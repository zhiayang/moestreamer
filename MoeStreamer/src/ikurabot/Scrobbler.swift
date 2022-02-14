// Client.swift
// Copyright (c) 2022, zhiayang
// SPDX-License-Identifier: Apache-2.0

import Socket
import CoreWLAN
import SwiftyJSON
import Foundation

class WifiDelegate : CWEventDelegate
{
	private weak var rpc: IkuraRPC? = nil

	init(rpc: IkuraRPC)
	{
		self.rpc = rpc
	}

	func ssidDidChangeForWiFiInterface(withName interfaceName: String)
	{
		guard let interface = CWWiFiClient.shared().interface(withName: interfaceName) else {
			self.rpc?.disconnect()
			return
		}

		self.rpc?.wifiSSIDChanged(to: interface.ssid())
	}
}

class IkuraRPC
{
	private var socket: Socket? = nil
	private var dispatch: DispatchQueue
	private var wifiDelegate: WifiDelegate!
	private var allowedSSIDs: [String] = []
	private var currentSSID: String? = nil

	init?(model: MainModel)
	{
		self.dispatch = DispatchQueue.init(label: "\(Bundle.main.bundleIdentifier ?? "").ikuraRPC")
		self.wifiDelegate = WifiDelegate(rpc: self)
		CWWiFiClient.shared().delegate = self.wifiDelegate

		model.subscribe(with: { song, state in
			if let song = song {
				self.updateSong(song)
			}
		})

		try? CWWiFiClient.shared().startMonitoringEvent(with: .linkDidChange)
		try? CWWiFiClient.shared().startMonitoringEvent(with: .ssidDidChange)
		try? CWWiFiClient.shared().startMonitoringEvent(with: .bssidDidChange)

		_ = Settings.observe(.ikuraWhitelistedSSIDs(), callback: { key in
			let whitelist: String = Settings.get(key)
			self.allowedSSIDs = whitelist.split(separator: ";").map({ String($0.trimmingCharacters(in: .whitespaces)) })
		})

		Settings.notifyObservers(for: .ikuraWhitelistedSSIDs())
	}

	deinit
	{
		try? CWWiFiClient.shared().stopMonitoringAllEvents()
		self.disconnect()
	}

	private func ssidWhitelistContains(ssid: String?) -> Bool
	{
		guard let ssid = ssid else {
			return false
		}
		return self.allowedSSIDs.contains(ssid)
	}

	private func updateSong(_ song: Song)
	{
		guard let socket = self.socket else {
			return
		}

		let json = JSON([
			"title": song.title,
			"artist": song.artists.joined(separator: ", ")
		])

		// note: no options = not pretty printed! the default options are to pretty print,
		// which we don't want (because it takes multiple lines)
		guard let ser = json.rawString(options: []) else {
			return
		}

		self.dispatch.async {
			_ = socket.tryWrite("/scrobble_song \(ser)\n")
		}
	}

	func connect() -> Bool
	{
		if !self.ssidWhitelistContains(ssid: CWWiFiClient.shared().interface()?.ssid()) {
			return false
		}

		self.socket = try? Socket.create()
		guard let socket = self.socket else {
			return false
		}

		let ip: String = Settings.get(.ikuraConsoleIp())
		let port: Int = Settings.get(.ikuraConsolePort())
		let password: String = Settings.getKeychain(.ikuraConsolePassword())

		do
		{
			try socket.connect(to: ip, port: Int32(port))
		}
		catch
		{
			Logger.log("ikura", msg: "failed to connect: \(error)")
			self.socket = nil
			return false
		}

		guard let foo = try? socket.readString(), foo.starts(with: "csrf: ") else {
			Logger.log("ikura", msg: "could not read CSRF")
			return false
		}

		let csrf = foo.components(separatedBy: .newlines)[0].dropFirst("csrf: ".count)
		guard socket.tryWrite(csrf + "\n") && socket.tryWrite(password + "\n") else {
			return false
		}

		print("ikura: connected")
		return true
	}

	func disconnect()
	{
		self.dispatch.async {
			_ = self.socket?.tryWrite("/q\n")
			self.socket = nil

			print("ikura: disconnected")
		}
	}

	func wifiSSIDChanged(to ssid: String?)
	{
		self.dispatch.async {
			guard self.currentSSID != ssid else {
				return
			}

			self.currentSSID = ssid
			guard self.ssidWhitelistContains(ssid: ssid) else {
				if self.socket != nil
				{
					Logger.log("ikura", msg: "ssid not in whitelist, disconnecting")
					self.disconnect()
				}
				return
			}

			// if we are disconnected, then connect automatically
			if self.socket == nil {
				// wait a while for the hardware to catch up
				self.dispatch.asyncAfter(deadline: .now() + 5) {
					Logger.log("ikura", msg: "ssid in whitelist, reconnecting")
					_ = self.connect()
				}
			}
		}
	}
}




fileprivate extension Socket
{
	func tryWrite(_ string: String) -> Bool
	{
		do
		{
			try self.write(from: string)
			return true
		}
		catch
		{
			Logger.log("ikura", msg: "write failed: \(error)")
			return false
		}
	}
}
