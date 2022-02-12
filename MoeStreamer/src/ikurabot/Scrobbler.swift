//
//  Scrobbler.swift
//  MoeStreamer
//
//  Created by zhiayang on 13/2/22.
//  Copyright © 2022 zhiayang. All rights reserved.
//

import Socket
import SwiftyJSON
import Foundation

class IkuraRPC
{
	private var socket: Socket? = nil

	init?(model: MainModel)
	{
		model.subscribe(with: { song, state in
			if let song = song {
				self.updateSong(song)
			}
		})
	}

	deinit
	{
		self.disconnect()
	}

	private func updateSong(_ song: Song)
	{
		let json = JSON([
			"title": song.title,
			"artist": song.artists.joined(separator: ", ")
		])

		do
		{
			// note: no options = not pretty printed!
			guard let ser = json.rawString(options: []) else {
				return
			}

			try self.socket?.write(from: "/scrobble_song \(ser)\n")
		}
		catch
		{
			Logger.log("ikura", msg: "write failed: \(error)")
		}
	}

	func connect() -> Bool
	{
		self.socket = try? Socket.create()
		guard self.socket != nil else {
			return false
		}

		let ip: String = Settings.get(.ikuraConsoleIp())
		let port: Int = Settings.get(.ikuraConsolePort())
		let password: String = Settings.getKeychain(.ikuraConsolePassword())

		do
		{
			try self.socket?.connect(to: ip, port: Int32(port))
		}
		catch
		{
			Logger.log("ikura", msg: "failed to connect: \(error)")
			return false
		}

		guard let foo = try? self.socket?.readString(), foo.starts(with: "csrf: ") else {
			Logger.log("ikura", msg: "could not read CSRF")
			return false
		}

		let csrf = foo.components(separatedBy: .newlines)[0].dropFirst("csrf: ".count)
		print("csrf = \(csrf)")

		do
		{
			try self.socket?.write(from: csrf + "\n")
			try self.socket?.write(from: password + "\n")
		}
		catch
		{
			Logger.log("ikura", msg: "write failed: \(error)")
			return false
		}

		return true
	}

	func disconnect()
	{
		_ = try? self.socket?.write(from: "/q\n")
	}
}
