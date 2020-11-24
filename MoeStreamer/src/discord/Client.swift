// Client.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Socket
import SwiftyJSON
import Foundation

fileprivate enum Opcode: UInt32
{
	case Handshake = 0
	case Frame     = 1
	case Close     = 2
	case Ping      = 3
	case Pong      = 4
}

class DiscordRPC
{
	private let rpcVersion = 1
	private let clientId = "780836425990012928"
	private let readIntervalMs: Int = 500

	private var socket: Socket?
	private var dispatch: DispatchQueue

	init?(model: MainModel)
	{
		self.dispatch = DispatchQueue.init(label: "\(Bundle.main.bundleIdentifier ?? "").receiveQueue")
		do {
			self.socket = try Socket.create(family: .unix, proto: .unix)
			try self.socket?.setBlocking(mode: false)
		} catch {
			Logger.log("discord", msg: "could not create ipc socket: \(self.getError(error))")
			return nil
		}

		model.subscribe(with: { song, state in
			if let song = song {
				self.updatePresence(with: song, state: state)
			}
		})
	}

	deinit
	{
		if self.socket != nil {
			let _ = self.send(opcode: .Close, msg: "")
			self.socket?.close()
		}
	}

	private func getError(_ e: Error) -> String
	{
		return (e as? Socket.Error)?.errorReason ?? "unknown error"
	}

	func connect() -> Bool
	{
		guard let socket = self.socket else {
			Logger.log("discord", msg: "no ipc socket")
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
			if !self.send(opcode: .Handshake, msg: JSON([ "v": self.rpcVersion, "client_id": self.clientId ]).rawString()!) {
				Logger.log("discord", msg: "handshake failed")
				return false
			}

			Logger.log("discord", msg: "connected to ipc socket")

			// setup the receiver.
			self.receive()
			self.subscribe(to: "ACTIVITY_JOIN")
			return true
		}

		Logger.log("discord", msg: "failed to connect to any ipc socket")
		return false
	}


	private func updatePresence(with song: Song, state: PlaybackState)
	{
		let json: [String: Any] = [
			"cmd": "SET_ACTIVITY",
			"args": [
				"pid": Int(getpid()),
				"activity": [
					"instance": true,
					"state": song.artists.isEmpty ? "-" : song.artists.joined(separator: ", "),
					"details": song.title,
					"assets": [
						"large_image": "default-cover",
						"large_text": "uwu"
					]
				]
			],
			"nonce": UUID().uuidString
		]

		let _ = self.send(opcode: .Frame, msg: JSON(json).rawString()!)
	}

	private func subscribe(to event: String)
	{
		let _ = self.send(opcode: .Frame, msg: JSON(["cmd": "SUBSCRIBE", "evt": event, "nonce": UUID().uuidString]).rawString()!)
	}

	private func handlePayload(opcode: Opcode, data: Data)
	{
		switch opcode
		{
			case .Close:
				self.socket!.close()
				Logger.log("discord", msg: "ipc socket closed")

			case .Ping:
				let _ = self.send(opcode: .Pong, msg: String(data: data, encoding: .utf8)!)

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

		if json["evt"]?.null != nil {
			return
		}

		guard let evt = json["evt"]?.string, let event = Event(rawValue: evt) else {
			Logger.log("discord", msg: "invalid event \(json["evt"]?.rawString() ?? "?")")
			return
		}

		switch event
		{
			case .Ready:
				Logger.log("discord", msg: "ipc ready")
				break

			case .Error:
				let code = json["code"]?.intValue ?? 0
				let message = json["message"]?.stringValue ?? "unknown"
				Logger.log("discord", msg: "error (\(code)): \(message)")
		}
	}

	private func receive()
	{
		self.dispatch.asyncAfter(deadline: .now() + .milliseconds(self.readIntervalMs)) {
			guard let socket = self.socket, socket.isConnected else {
				return
			}

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

	private func send(opcode: Opcode, msg: String) -> Bool
	{
		if self.socket == nil || !self.socket!.isConnected {
			return false
		}

		let data = msg.data(using: .utf8)!
		let buf = UnsafeMutableRawBufferPointer.allocate(byteCount: 8 + data.count, alignment: 1)
		defer { buf.deallocate() }

		buf.storeBytes(of: opcode.rawValue, toByteOffset: 0, as: UInt32.self)
		buf.storeBytes(of: UInt32(data.count), toByteOffset: 4, as: UInt32.self)
		data.copyBytes(to: (buf.baseAddress! + 8).assumingMemoryBound(to: UInt8.self), count: data.count)

		do {
			try self.socket?.write(from: buf.baseAddress!, bufSize: buf.count)
			return true
		} catch {
			Logger.log("discord", msg: "send failed: \(self.getError(error))")
			return false
		}
	}
}



