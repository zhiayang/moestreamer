// ListenMoe.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Just
import Cocoa
import Foundation
import Starscream
import SwiftyJSON



class ListenMoeSession
{
	private let apiURL = URL(string: "https://listen.moe/api")!
	private var token: String? = nil

	private var username: String = ""
	private var password: String = ""

	private var defaultHeaders = [
		"Accept": "application/vnd.listen.v4+json"
	]

	private var just: JustOf<HTTP> = Just
	private var activityView: ViewModel?

	init(activityView: ViewModel?, performLogin: Bool)
	{
		self.activityView = activityView
		self.just = JustOf<HTTP>(defaults: JustSessionDefaults(headers: self.defaultHeaders))

		if performLogin {
			DispatchQueue.global().async {
				self.login()
			}
		}
	}

	func setViewModel(viewModel: ViewModel)
	{
		self.activityView = viewModel
	}

	func login(force: Bool = false, activityView: ViewModel? = nil, onSuccess: (() -> Void)? = nil)
	{
		self.username = Settings.get(.listenMoeUsername())
		self.password = Settings.getKeychain(.listenMoePassword())

		let actView = activityView ?? self.activityView

		// already logged in.
		if self.isLoggedIn() && !force {
			Logger.log("listen.moe", msg: "already logged in", withView: actView)
			return
		}

		// cannot log in.
		if self.username.isEmpty || self.password.isEmpty {
			return
		}

		actView?.spin()

		let route = self.apiURL.appendingPathComponent("login")
		just.post(route, json: [ "username": self.username, "password": self.password ]) { (resp) in

			// we can't do this in this thread, because we're not supposed to poke the UI
			// from another thread -- and the http response handler presumably does not run
			// in the UI thread (for obvious reasons).

			if (200...299).contains(resp.statusCode!)
			{
				self.token = JSON(parseJSON: resp.text!)["token"].string!
				Logger.log("listen.moe", msg: "logged in!", withView: actView)

				if !self.token!.isEmpty
				{
					// update the default headers.
					self.defaultHeaders["Authorization"] = "Bearer \(self.token!)"
					self.just = JustOf<HTTP>(defaults: JustSessionDefaults(headers: self.defaultHeaders))
				}

				// call the handler, if any
				onSuccess?()

				// this is a nasty (visual) hack -- we need the parent to be poked so it
				// can update buttons (eg. logging in lets us favourite songs). BUT, if we
				// poke the parent before the child animation is finished, then the child's animation
				// will be cancelled. this is important for the login button in the settings page.
				// so, we must delay the poking by some amount of time.
				DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
					self.activityView?.poke()
				}
			}
			else if resp.statusCode! == 401
			{
				Logger.error("listen.moe", msg: "invalid login credentials", withView: actView)
			}
			else
			{
				let msg = "\(resp.statusCode!) - \(JSON(parseJSON: resp.text!)["message"].string!)"
				Logger.log("listen.moe", msg: msg, withView: actView)
			}

			actView?.unspin()
		}
	}

	func isLoggedIn() -> Bool
	{
		return !self.token.isNilOrEmpty
	}

	func checkResponse<T>(resp: HTTPResult, onSuccess: @escaping (HTTPResult) -> T, onFailure: ((HTTPResult) -> Void)? = nil) -> T?
	{
		if (200...299).contains(resp.statusCode!) {
			return onSuccess(resp)
		}
		else if resp.statusCode! == 401
		{
			Logger.error("listen.moe", msg: "not logged in", withView: self.activityView)
			onFailure?(resp)
			return nil
		}
		else
		{
			let err = "\(resp.statusCode!) - \(JSON(parseJSON: resp.text!)["message"].string!)"
			Logger.error("listen.moe", msg: err, withView: self.activityView)

			onFailure?(resp)
			return nil
		}
	}

	func isFavourite(song: Song) -> Bool
	{
		if self.username.isEmpty || self.token == nil {
			return false
		}

		let route = self.apiURL.appendingPathComponent("favorites").appendingPathComponent(self.username)
		return checkResponse(resp: just.get(route), onSuccess: { resp in
			if let favs = JSON(parseJSON: resp.text!)["favorites"].array {
				if let _ = favs.first(where: { (fav) in
					return song.id == fav["id"].int
				}) {
					return true
				}
			}
			return false

		}) ?? false
	}


	func favouriteSong(song: Song, con: ListenMoeController)
	{
		let route = self.apiURL.appendingPathComponent("favorites").appendingPathComponent("\(song.id)")
		just.post(route) { (resp) in

			self.checkResponse(resp: resp, onSuccess: { resp in
				var s = song
				if con.getCurrentSong()?.id == s.id
				{
					s.isFavourite.finalise()
					con.setCurrentSong(song: s, quiet: true)

					Logger.log("listen.moe", msg: "favourited \(s.title)", withView: self.activityView)
					self.activityView?.poke()
				}
			}, onFailure: { _ in
				var s = song
				s.isFavourite.cancel()

				con.setCurrentSong(song: s, quiet: true)
				self.activityView?.poke()
			})
		}
	}

	func unfavouriteSong(song: Song, con: ListenMoeController)
	{
		let route = self.apiURL.appendingPathComponent("favorites").appendingPathComponent("\(song.id)")
		just.delete(route) { (resp) in

			self.checkResponse(resp: resp, onSuccess: { resp in
				var s = song
				if con.getCurrentSong()?.id == s.id
				{
					s.isFavourite.finalise()
					con.setCurrentSong(song: s, quiet: true)

					Logger.log("listen.moe", msg: "unfavourited \(s.title)", withView: self.activityView)
					self.activityView?.poke()
				}
			}, onFailure: { _ in
				var s = song
				s.isFavourite.cancel()

				con.setCurrentSong(song: s, quiet: true)
				self.activityView?.poke()
			})
		}
	}
}


class ListenMoeController : ServiceController, WebSocketDelegate
{
	private let streamURL    = URL(string: "https://listen.moe/stream")!
	private let websocketURL = URL(string: "wss://listen.moe/gateway_v2")!
	private let coverArtURL  = URL(string: "https://cdn.listen.moe/covers")!

	private var socket: WebSocket

	// if you didn't log in, this will be nil.
	private var loginSession: ListenMoeSession

	private var currentSong: Song? = nil
	private var activityView: ViewModel?
	private var pingTimer: Timer? = nil

	private var audioCon: AudioController

	required init()
	{
		self.socket = WebSocket(url: self.websocketURL)

		// uwu 
		self.socket.disableSSLCertValidation = true

		// try to login.
		self.loginSession = ListenMoeSession(activityView: nil,
											 performLogin: Settings.get(.shouldAutoLogin()))

		self.audioCon = AudioController(url: self.streamURL, pauseable: false)

		self.socket.delegate = self
		self.socket.connect()
	}

	func setViewModel(viewModel: ViewModel)
	{
		self.activityView = viewModel
		self.loginSession.setViewModel(viewModel: viewModel)
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
		if self.loginSession.isLoggedIn() || true {
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
		self.stop()
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
			if !quiet
			{
				Logger.log(msg: "song: \(song.title)")
				Notifier.instance?.notify(song: song)
			}

//			self.activityView?.onSongChange(song: song)
			Statistics.instance.logSongPlayed()
		}

		self.currentSong = song
		self.activityView?.onSongChange(song: song)
//		self.activityView?.poke()
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
			do {
				var s = Song(id: song["id"].int!)

				s.title = song["title"].string!
				for x in song["artists"].array!
				{
					if let artist = x["name"].string {
						s.artists.append(artist)
					}
				}


				// the strategy here is to find the first album entry with cover art.
				var album: (String?, NSImage?) = (nil, nil)
				for x in song["albums"].array!
				{
					let cov = x["image"].string
					if album.0 == nil || (album.1 == nil && cov != nil)
					{
						album.0 = x["name"].string!
						if let img = cov {
							let url = self.coverArtURL.appendingPathComponent(img)
							album.1 = NSImage(contentsOf: url)
						}
					}
				}

				s.album = album

				// update the current song info.
				s.isFavourite = self.loginSession.isFavourite(song: s) ? .Yes : .No
				self.setCurrentSong(song: s)

				self.activityView?.unspin()
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

	// unused.
	func websocketDidConnect(socket: WebSocketClient) {	}
	func websocketDidDisconnect(socket: WebSocketClient, error: Error?) { }
	func websocketDidReceiveData(socket: WebSocketClient, data: Data) { }
}
