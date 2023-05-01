// Client.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Just
import Cocoa
import Socket
import SwiftyJSON
import Foundation

enum Opcode: UInt32
{
	case Handshake = 0
	case Frame     = 1
	case Close     = 2
	case Ping      = 3
	case Pong      = 4
}

fileprivate struct Asset : Equatable
{
	var id: String
	var name: String
	var hash: String { return self.hashValue.hexString }
	var hashValue: AlbumHash

	init(id: String, name: String, hash: AlbumHash)
	{
		self.id = id
		self.name = name
		self.hashValue = hash
	}
}

// fnv-1a
fileprivate func hash(of string: String) -> AlbumHash
{
	let prime: UInt64 = 1099511628211
	let offset: UInt64 = 14695981039346656037

	var ret = offset
	for b in string.utf8
	{
		ret ^= UInt64(b)
		ret = ret &* prime
	}

	return ret
}

fileprivate func getLocalDiscordToken() -> String?
{
	guard let appsup = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
		print("could not find Application Support folder (what...)")
		return nil
	}

	let db_dir = appsup.appendingPathComponent("discord/Local Storage/leveldb/")
	do {
		let dbs = try FileManager.default.contentsOfDirectory(at: db_dir, includingPropertiesForKeys: [
			.contentModificationDateKey
		], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])

		let sorted_ldbs = try dbs.filter({ $0.lastPathComponent.hasSuffix(".ldb") || $0.lastPathComponent.hasSuffix(".log") }).sorted(by: {
			let date0 = try $0.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
			let date1 = try $1.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
			return date0.compare(date1) == .orderedDescending
		})

		for ldb in sorted_ldbs
		{
			do {
				let contents = try Data(contentsOf: ldb)
				if let range = contents.firstRange(of: "mfa.".data(using: .utf8)!) {
					let token = contents[range.startIndex ..< range.endIndex + 84]
					return token.toString()
				}

			} catch {
				print("failed to read file \(ldb.lastPathComponent): \(error)")
				continue
			}
		}

	} catch {
		print("failed to get discord data: \(error)")
	}

	return nil
}





class DiscordRPC
{
	private static let rpcVersion = 1
	private static let assetLimit = 148 // conservatively
	private static let defaultClientId = "780836425990012928"

	private let just: JustOf<HTTP>
	private var readIntervalMs: Int = 500

	private var socket: Socket? = nil
	private var dispatch: DispatchQueue
	private var rateLimiter: RateLimiter!
	private var uploadToken = Synchronised<(String?, Bool)>(value: (nil, false))

	// part of me feels like this is super thread-unsafe, and that part of me would be right.
	private var cancelPresenceUpdate: Bool = false
	private var existingRemoteAssets: [AlbumHash: Asset] = [:]

	// wait 8 seconds before re-asking discord for the list of assets
	private let assetUploadConfirmationInterval: Double = 8

	private let assetsURL: URL
	private let clientId: String

	init?(model: MainModel)
	{
		let appid: String = Settings.get(.discordAppId())
		self.clientId = appid.isEmpty ? DiscordRPC.defaultClientId : appid
		self.assetsURL = URL(string: "https://discord.com/api/v8/oauth2/applications/\(self.clientId)/assets")!


		self.dispatch = DispatchQueue.init(label: "\(Bundle.main.bundleIdentifier ?? "").discordRPC")

		self.just = JustOf<HTTP>(defaults: JustSessionDefaults())
		self.rateLimiter = RateLimiter(5, every: 21, callback: self.updatePresence, dispatch: self.dispatch)

		// start at 500ms.
		self.readIntervalMs = 500
		self.socket = self.createSocket()

		model.subscribe(with: { song, state in
			if let song = song {
				self.rateLimiter.enqueueUpdate(for: song, state: state)
			}
		})

		self.loadDiscordToken()
	}

	deinit
	{
		self.disconnect()
	}

	private func loadDiscordToken()
	{
		if !Settings.get(.discordAutoFetchToken())
		{
			let token = Settings.getKeychain(.discordUserToken())
			if !token.isEmpty
			{
				self.uploadToken.set(value: (token, true))
				Logger.log("discord", msg: "loaded auth token")
				return
			}
		}

		let _ = Settings.observe(.discordUserToken(), callback: { key in
			let token = Settings.getKeychain(.discordUserToken())
			guard !token.isEmpty else { return }

			Logger.log("discord", msg: "token updated")
			self.uploadToken.set(value: (token, true))
		})

		DispatchQueue.main.async {
			if let token = getLocalDiscordToken()
			{
				self.uploadToken.set(value: (token, true))
				Logger.log("discord", msg: "found auth token")
			}
		}
	}

	private func createSocket() -> Socket?
	{
		do {
			let socket = try Socket.create(family: .unix, proto: .unix)
			try socket.setBlocking(mode: false)
			return socket
		} catch {
			Logger.log("discord", msg: "could not create ipc socket: \(getErrorString(for: error))")
			return nil
		}
	}

	private func reconnect()
	{
		self.socket = nil

		Logger.log("discord", msg: "lost ipc socket, reconnecting")
		self.dispatch.asyncAfter(deadline: .now() + 3) {
			self.socket = self.createSocket()
			let _ = self.connect()
		}
	}

	func disconnect()
	{
		let _ = self.socket?.send(opcode: .Close, msg: "")
		self.socket?.close()
		self.socket = nil
	}

	func connect() -> Bool
	{
		guard let socket = self.socket else {
			Logger.log("discord", msg: "no socket, aborting")
			return false
		}

		for i in 0 ..< 10
		{
			let tmp = NSTemporaryDirectory()
			let ipc = "\(tmp)/discord-ipc-\(i)"

			try? socket.connect(to: ipc)

			if !socket.isConnected {
				continue
			}

			// handshake.
            if !socket.send(opcode: .Handshake, json: JSON([ "v": DiscordRPC.rpcVersion, "client_id": self.clientId ] as [String: Any])) {
				Logger.log("discord", msg: "handshake failed")
				return false
			}

			Logger.log("discord", msg: "connected to ipc socket")

			// setup the receiver.
			self.receive()
			self.updateExistingAssets()
			return true
		}

		Logger.log("discord", msg: "failed to connect to any ipc socket")
		self.socket = nil
		return false
	}

	private func updatePresence(with song: Song, state: PlaybackState)
	{
		guard let socket = self.socket else {
			return
		}

		if !socket.isConnected {
			self.reconnect()
			return
		}

		let dict: [String: Any]
		if state.playing
		{
			self.cancelPresenceUpdate = false
			let endTime = song.duration.map({ Int(Date().addingTimeInterval($0 - state.elapsed).timeIntervalSince1970) })
				?? (-1)

			// if possible, this will also asynchronously upload the art if it didn't already exist remotely,
			// and re-send a presence update once we have it uploaded.
			let asset = self.getAlbumArtAsset(for: song, callback: {
				print("re-sent presence update")
				let dict = self.constructPresenceUpdate(for: song, ending: endTime, using: $0)
				let _ = socket.send(opcode: .Frame, json: JSON(dict))
			})

			dict = self.constructPresenceUpdate(for: song, ending: endTime, using: asset)
		}
		else
		{
			self.cancelPresenceUpdate = true
			dict = [
				"cmd": "SET_ACTIVITY",
				"nonce": UUID().uuidString,
				"args": [ "pid": Int(getpid()) ]
			]
		}

		let _ = socket.send(opcode: .Frame, json: JSON(dict))
	}

	private func constructPresenceUpdate(for song: Song, ending ts: Int, using asset: Asset?) -> [String: Any]
	{
		return [
			"cmd": "SET_ACTIVITY",
			"nonce": UUID().uuidString,
			"args": [
				"pid": Int(getpid()),
				"activity": [
					"instance": true,
					"details": song.title,
					"state": song.artists.isEmpty ? "-" : song.artists.joined(separator: ", "),
					"assets": [
						"large_image": (asset != nil) ? "album-art-\(asset!.hash)" : "default-cover",
						"large_text": song.title
					] as [String: Any],
					"timestamps": ts == -1 ? [String: Any]() : [
						"end": ts
					] as [String: Any]
				] as [String: Any]
			] as [String: Any]
		]
	}




	private func getAlbumArtAsset(for song: Song, callback: @escaping (Asset) -> Void) -> Asset?
	{
		let uploadToken = self.uploadToken.value()
		guard uploadToken.1, let token = uploadToken.0, let albumName = song.album.0 else {
			return nil
		}

		// don't try to upload for listen moe, we'll run out of space.
		if song.source == .ListenMoe() {
			return nil
		}

		let albumHash = hash(of: albumName)

		// if it exists in our list, then just return it.
		if let existing = self.existingRemoteAssets[albumHash] {
			return existing
		}

		guard let art = song.album.1, let base64 = art.base64Encoded() else {
			return nil
		}

		// at this point, we *should* be able to upload it, barring any remote-related errors.
		self.dispatch.async {
			// if we have hit the limit, we need to start yeeting images. we shouldn't need to worry about
			// the rate limit here, because in most circumstances we'll just be deleting 1 or 2 assets.
			while self.existingRemoteAssets.count >= DiscordRPC.assetLimit
			{
				let victim = self.existingRemoteAssets.first!

				let resp = self.just.delete(self.assetsURL.appendingPathComponent("\(victim.value.id)"))
				if !(200...299).contains(resp.statusCode!) {
					print("failed to delete old album art: \(resp.text ?? "?")")
					continue
				}

				self.existingRemoteAssets.removeValue(forKey: victim.key)
			}

			Logger.log("discord", msg: "attempting to upload art for album \(albumName) (hash \(albumHash.hexString))")

			let resp = self.just.post(self.assetsURL, json: [
				"image": base64,
				"name": "album-art-\(albumHash.hexString)",
				"type": 1
			] as [String: Any], headers: ["Authorization": token])

			guard let status = resp.statusCode, let body = resp.text, (200...299).contains(status) else {
				Logger.log("discord", msg: "failed to upload art; error: \(resp.text ?? "none")")
				return
			}

			let json = JSON(parseJSON: body)
			let asset = Asset(id: json["id"].stringValue, name: json["name"].stringValue, hash: albumHash)
			self.existingRemoteAssets.updateValue(asset, forKey: albumHash)

			Logger.log("discord", msg: "uploaded art for album \(albumName) (hash \(albumHash.hexString)")


			// now, send another presence update... after a few seconds in case discord is pepega.
			// if we got cancelled, then... don't.
			if self.cancelPresenceUpdate {
				self.cancelPresenceUpdate = false
				return
			}

			self.resendPresence(for: asset, using: callback)
		}

		// still return nil, lmao
		return nil
	}

	private func resendPresence(for asset: Asset, using callback: @escaping (Asset) -> Void)
	{
		self.dispatch.asyncAfter(deadline: .now() + self.assetUploadConfirmationInterval) {
			self.updateExistingAssets()

			if self.existingRemoteAssets[asset.hashValue] != nil {
				callback(asset)
			} else {
				self.resendPresence(for: asset, using: callback)
			}
		}
	}

	private func updateExistingAssets()
	{
		let uploadToken = self.uploadToken.value()
		guard uploadToken.1, let token = uploadToken.0 else {
			return
		}

		// no need authorisation to read the asset list.
		let resp = Just.get(self.assetsURL, headers: ["Authorization": token])
		guard resp.ok && resp.text != nil else {
			print("failed to update assets: \(resp.statusCode ?? 0)")
			return
		}

		let json = JSON(parseJSON: resp.text!)
		let list = json.arrayValue
			.map { $0.dictionaryValue }
			.map { (obj: [String: JSON]) -> Asset? in
				let prefix = "album-art-"

				guard let id = obj["id"]?.string, let name = obj["name"]?.string, name.starts(with: prefix) else {
					return nil
				}

				let substr = name[name.index(name.startIndex, offsetBy: prefix.count)...]
				guard let hash = UInt64.from(hexString: substr) else {
					return nil
				}

				return Asset(id: id, name: name, hash: hash)
			}
			.filter({ $0 != nil })
			.map({ ($0!.hashValue, $0!) })

		self.existingRemoteAssets = Dictionary(list, uniquingKeysWith: { $1 })
	}

	private func handlePayload(opcode: Opcode, data: Data)
	{
		guard let socket = self.socket else {
			return
		}

		switch opcode
		{
			case .Close:
				socket.close()
				Logger.log("discord", msg: "ipc socket closed")

			case .Ping:
				let _ = socket.send(opcode: .Pong, msg: String(data: data, encoding: .utf8)!)

			case .Frame:
				try? self.handle(json: JSON(data: data).dictionaryValue)

			default:
				return
		}
	}

	private func handle(json: [String: JSON])
	{
		enum Event: String
		{
			case Ready = "READY"
			case Error = "ERROR"
		}

		guard let evt = json["evt"]?.string, let event = Event(rawValue: evt) else {
			// if there was a nonce, it's a response. since, we didn't parse an "ERROR",
			// then it must be a success, so we can just ignore it.
			if json["nonce"]?.exists() == false {
				print("invalid event \(json["evt"]?.rawString() ?? "?")")
			}
			return
		}

		switch event
		{
			case .Ready:
				Logger.log("discord", msg: "ipc ready")

			case .Error:
				let code = json["code"]?.intValue ?? 0
				let message = json["data"]?.dictionary?["message"]?.string ?? "unknown"
				print("error (\(code)): \(message)")
		}
	}


	private func receive()
	{
		self.dispatch.asyncAfter(deadline: .now() + .milliseconds(self.readIntervalMs)) {
			guard let socket = self.socket else {
				return
			}

			if !socket.isConnected {
				self.reconnect()
				return
			}

			// gradually increase the interval, because we don't actually care about
			// what discord is telling us.
			self.readIntervalMs = min(10000, self.readIntervalMs * 2);

			// re-queue the next one
			self.receive()

			do {
				let buf = UnsafeMutablePointer<Int8>.allocate(capacity: 8)
				let ptr = UnsafeRawPointer(buf)
				defer { buf.deallocate() }

				var n = try socket.read(into: buf, bufSize: 8, truncate: true)
				if n <= 0 {
					return
				}

				let op = ptr.load(fromByteOffset: 0, as: UInt32.self)
				let sz = ptr.load(fromByteOffset: 4, as: UInt32.self)

				guard let opcode = Opcode(rawValue: op), sz > 0 else {
					return
				}

				let size = Int(sz)

				let bodyBuf = UnsafeMutablePointer<Int8>.allocate(capacity: size)
				let bodyPtr = UnsafeRawPointer(bodyBuf)
				defer { bodyBuf.deallocate() }

				n = try socket.read(into: bodyBuf, bufSize: size, truncate: true)
				if n <= 0 {
					return
				}

				self.handlePayload(opcode: opcode, data: Data(bytes: bodyPtr, count: size))

			} catch {
				// print(self.getError(error))
				return
			}
		}
	}
}

fileprivate func getErrorString(for error: Error) -> String
{
	return (error as? Socket.Error)?.errorReason ?? "unknown error"
}
