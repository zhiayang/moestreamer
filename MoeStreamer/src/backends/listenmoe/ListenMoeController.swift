// ListenMoeController.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import SwiftyJSON
import Starscream
import Foundation

class ListenMoeController : ServiceController, WebSocketDelegate
{
	private let streamURL    = URL(string: "https://listen.moe/stream")!
	private let websocketURL = URL(string: "wss://listen.moe/gateway_v2")!
	private let coverArtURL  = URL(string: "https://cdn.listen.moe/covers")!

	private var socket: WebSocket

	// if you didn't log in, this will be nil.
	private var loginSession: ListenMoeSession

	private var currentSong: Song? = nil
	private var activityView: ViewModel? = nil
	private var pingTimer: Timer? = nil
	private var isPlaying: Bool = false

	private var audioCon: StreamAudioController
	private var lastSongChange = Date()

	required init(viewModel: ViewModel?)
	{
		self.socket = WebSocket(url: self.websocketURL)

		self.activityView = viewModel

		// uwu
		self.socket.disableSSLCertValidation = true

		// try to login.
		self.loginSession = ListenMoeSession(activityView: nil,
											 performLogin: Settings.get(.listenMoeAutoLogin()))

		self.audioCon = StreamAudioController(url: self.streamURL, pauseable: false)

		self.socket.delegate = self
		self.socket.connect()
	}

	func setViewModel(viewModel: ViewModel)
	{
		self.activityView = viewModel
		self.loginSession.setViewModel(viewModel: viewModel)
	}

	func getViewModel() -> ViewModel?
	{
		return self.activityView
	}

	func audioController() -> AudioController
	{
		return self.audioCon
	}

	func sessionLogin(activityView: ViewModel?, force: Bool)
	{
		// try to login again.
		self.loginSession.login(force: force, activityView: activityView) {
			// on success, see if the song is currently a favourite.
			if var s = self.getCurrentSong() {
				s.isFavourite = self.loginSession.isFavourite(song: s) ? .Yes : .No
				self.setCurrentSong(song: s)
			}
		}
	}

	func getCapabilities() -> ServiceCapabilities
	{
		if self.loginSession.isLoggedIn() {
			return [ .favourite ]
		} else {
			return [ ]
		}
	}



	func start()
	{
		self.stop()

		self.activityView?.spin()
		self.socket.connect()
	}

	func pause()
	{
		// this doesn't do anything, since the audio stream is independent of the metadata.
		// we do not disconnect the websocket, so we can keep updating the songs and stuff.
	}

	func refresh()
	{
		// try to log in (again)
		self.sessionLogin(activityView: self.activityView, force: false)

		// restart the socket connection.
		self.start()
	}

	func stop()
	{
		if self.socket.isConnected {
			self.socket.disconnect()
		}

		self.pingTimer?.invalidate()
	}

	func getCurrentSong() -> Song?
	{
		return self.currentSong
	}

	func setCurrentSong(song: Song, quiet: Bool = false)
	{
		if self.currentSong?.id != song.id
		{
			if !quiet {
				Logger.log(msg: "song: \(song.title)")
			}

			Statistics.instance.logSongPlayed()
		}

		self.currentSong = song
		self.activityView?.onSongChange(song: song)
		self.lastSongChange = Date()
	}

	func toggleFavourite()
	{
		// toggles the current favourite song.
		if self.currentSong != nil
		{
			// this only sets the icon to pending.
			self.currentSong?.isFavourite.toggle()

			// after the POST request is done, we will finalise the favourited state in the callback.
			if self.currentSong!.isFavourite.bool {
				self.loginSession.favouriteSong(song: self.currentSong!, con: self)
			} else {
				self.loginSession.unfavouriteSong(song: self.currentSong!, con: self)
			}

			self.activityView?.onSongChange(song: self.currentSong)
		}
	}

	// websocket update function
	func websocketDidReceiveMessage(socket: WebSocketClient, text: String)
	{
		let json = JSON(parseJSON: text)

		if json["op"].int == 0
		{
			if let interval = json["d"]["heartbeat"].double {
				self.pingTimer = Timer.scheduledTimer(withTimeInterval: interval / 1000, repeats: true) { _ in
					let ping = JSON(dictionaryLiteral: ("op", 9))
					self.socket.write(string: ping.rawString()!)
				}
			}
		}
		else if json["op"].int == 1
		{
			let song = json["d"]["song"]

			DispatchQueue.global().async {

				var s = Song(id: song["id"].int!, source: .ListenMoe())

				s.title = song["title"].string!
				for x in song["artists"].array!
				{
					if let artist = x["name"].string {
						s.artists.append(artist)
					}
				}


				// the strategy here is to find the first album entry with cover art.
				var album: (String?, NSImage?) = (nil, nil)
				var coverArtURL: URL? = nil

				for x in song["albums"].array!
				{
					let cov = x["image"].string
					if album.0 == nil || (album.1 == nil && cov != nil)
					{
						album.0 = x["name"].string!
						if let img = cov {
							let url = self.coverArtURL.appendingPathComponent(img)
							coverArtURL = url
						}
					}
				}

				s.album = album

				// update the current song info.
				s.isFavourite = self.loginSession.isFavourite(song: s) ? .Yes : .No
				self.setCurrentSong(song: s)

				if let cov = coverArtURL
				{
					DispatchQueue.global().async {
						var _s = s
						_s.album.1 = NSImage(contentsOf: cov)

						self.setCurrentSong(song: _s)
						self.activityView?.unspin()
					}
				}
				else
				{
					self.activityView?.unspin()
				}
			}
		}
		else if json["op"].int == 10
		{
			// this is the pong for our ping -- just ignore it.
		}
		else
		{
			print("got unknown response with opcode \(json["op"].int!)")
		}
	}

	func getElapsedTime() -> Double
	{
		return self.lastSongChange.timeIntervalSinceNow * -1
	}

	func isReady() -> Bool
	{
		return self.currentSong != nil
	}

	// unused.
	func websocketDidConnect(socket: WebSocketClient) {	}
	func websocketDidDisconnect(socket: WebSocketClient, error: Error?) { }
	func websocketDidReceiveData(socket: WebSocketClient, data: Data) { }
}
