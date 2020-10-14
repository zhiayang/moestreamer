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
	private let apiURL = URL(string: "https://listen.moe/graphql")!
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
		if self.isLoggedIn() && !force
		{
//			onSuccess?()
			return
		}

		// cannot log in.
		if self.username.isEmpty || self.password.isEmpty {
			return
		}

		self.token = nil
		actView?.spin()

		// apparently listen.moe moved from a simple, perfectly fine REST api to some heckin "graphql"
		// monstrosity that's a shitty implementation of RPC on top of JSON on top of HTTP on top of TCP
		// i don't want to deal with whatever nonsensical libraries, so i'm just going to construct and
		// send the json manually.
		let graphql_query = """
		mutation login($username: String!, $password: String!) {
			login(username: $username, password: $password) {
				user {
					uuid
					username
				}
				token
			}
		}
		"""

		let query: [String: Any] = [
			"operationName": "login",
			"variables": [ "username": self.username, "password": self.password ],
			"query": graphql_query
		]

		just.post(self.apiURL, json: query, asyncCompletionHandler: { (resp) in

			// we can't do this in this thread, because we're not supposed to poke the UI
			// from another thread -- and the http response handler presumably does not run
			// in the UI thread (for obvious reasons).

			actView?.unspin()
			if let error = resp.error
			{
				Logger.error("listen.moe", msg: "error while logging in: \(error)")
				return;
			}

			guard let statusCode = resp.statusCode else {
				return;
			}

			if (200...299).contains(statusCode) && resp.text != nil
			{
				if let token = JSON(parseJSON: resp.text!)["data"]["login"]["token"].string, !token.isEmpty
				{
					self.token = token
					Logger.log("listen.moe", msg: "logged in!", withView: actView)

					// update the default headers.
					self.defaultHeaders["Authorization"] = "Bearer \(self.token!)"
					self.just = JustOf<HTTP>(defaults: JustSessionDefaults(headers: self.defaultHeaders))

					// call the handler, if any
					 onSuccess?()
				}
				else
				{
					Logger.error("listen.moe", msg: "login failed!")
				}

				// this is a nasty (visual) hack -- we need the parent to be poked so it
				// can update buttons (eg. logging in lets us favourite songs). BUT, if we
				// poke the parent before the child animation is finished, then the child's animation
				// will be cancelled. this is important for the login button in the settings page.
				// so, we must delay the poking by some amount of time.
				DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
					self.activityView?.poke()
				}
			}
			else if statusCode == 401
			{
				Logger.error("listen.moe", msg: "invalid login credentials", withView: actView)
			}
			else
			{
				let msg = "\(statusCode) - \(JSON(parseJSON: resp.text ?? "")["message"].string ?? "response: \(resp.text ?? "none")")"
				Logger.log("listen.moe", msg: msg, withView: actView)
			}
		})
	}

	func isLoggedIn() -> Bool
	{
		return !self.token.isNilOrEmpty
	}

	func checkResponse<T>(resp: HTTPResult, onSuccess: @escaping (HTTPResult) -> T, onFailure: ((HTTPResult) -> Void)? = nil) -> T?
	{
		if (200...299).contains(resp.statusCode!)
		{
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
			let err = "\(resp.statusCode!) - \(JSON(parseJSON: resp.text!)["message"].string ?? "response: \(resp.text!)")"
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

		let graphql_query = """
		query checkFavorite($songs: [Int!]!) {
			checkFavorite(songs: $songs)
		}
		"""

		let query: [String: Any] = [
			"operationName": "checkFavorite",
			"variables": [
				"songs": [ song.id ]
			],
			"query": graphql_query
		]
		return checkResponse(resp: just.post(self.apiURL, json: query), onSuccess: { resp in
			if let favs = JSON(parseJSON: resp.text!)["data"]["checkFavorite"].array {
				return favs.first(where: { (fav) in
					fav.int == song.id
				}) != nil
			}
			return false

		}) ?? false
	}

	// note: because the API operates on a toggling basis (which is really heckin dumb),
	// there is a possibility of a desync between the ui and the actual state. you can
	// fix that by refreshing though, so it isn't that bad.
	func setFavouriteState(fav: Bool, song: Song, con: ListenMoeController)
	{
		if self.username.isEmpty || self.token == nil {
			return
		}

		let graphql_query = """
		mutation favoriteSong($id: Int!) {
			favoriteSong(id: $id) {
				id
			}
		}
		"""

		let query: [String: Any] = [
			"operationName": "favoriteSong",
			"variables": [
				"id": song.id
			],
			"query": graphql_query
		]

		just.post(self.apiURL, json: query, asyncCompletionHandler: { (resp) in

			self.checkResponse(resp: resp, onSuccess: { resp in
				var s = song
				if con.getCurrentSong()?.id == s.id
				{
					s.isFavourite.finalise()
					con.setCurrentSong(song: s, quiet: true)
				}

				Logger.log("listen.moe", msg: "\(fav ? "" : "un")favourited \(s.title)", withView: self.activityView)
				self.activityView?.poke()

			}, onFailure: { _ in
				var s = song
				s.isFavourite.cancel()

				con.setCurrentSong(song: s, quiet: true)
				self.activityView?.poke()
			})
		})
	}


	func favouriteSong(song: Song, con: ListenMoeController)
	{
		setFavouriteState(fav: true, song: song, con: con)
	}

	func unfavouriteSong(song: Song, con: ListenMoeController)
	{
		setFavouriteState(fav: false, song: song, con: con)
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
	private var activityView: ViewModel? = nil
	private var pingTimer: Timer? = nil
	private var isPlaying: Bool = false

	private var audioCon: StreamAudioController

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

	func nextSong()
	{
		// we cannot
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

			DispatchQueue.global().async {
				
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

	func isReady() -> Bool
	{
		return self.currentSong != nil
	}

	// unused.
	func websocketDidConnect(socket: WebSocketClient) {	}
	func websocketDidDisconnect(socket: WebSocketClient, error: Error?) { }
	func websocketDidReceiveData(socket: WebSocketClient, data: Data) { }
}
