// MainModel.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import SwiftUI
import Foundation

class MainModel : ViewModel, ObservableObject
{
	@Published private var musicCon: ServiceController!
	@Published var dummy: Bool = false

	@Published var status: String = ""
	@Published var spinning: Int = 0

	@Published var songTitle: String = ""
	@Published var songArtist: String = ""
	@Published var albumArt: AnyView?

	// state for view-specific shenanigans
	@Published var textOpacity: Double = 1.0
	@Published var favOpacity: Double = 0.0
	@Published var truncateArtists: Bool = false

	private var currentSong: Song? = nil
	private var subscribers: [(Song?, PlaybackState) -> Void] = []

	var isPlaying: Bool = false {
		didSet {
			if isPlaying
			{
				if self.musicCon.isReady()
				{
					self.musicCon.start()
					self.musicCon.audioController().play()
				}
				else
				{
					self.isPlaying = false
				}
			}
			else
			{
				self.musicCon.audioController().pause()
				self.musicCon.pause()
			}

			for sub in self.subscribers {
				sub(self.currentSong, self.getPlaybackState())
			}
		}
	}

	var isMuted: Bool {
		get { self.musicCon.audioController().isMuted() }
		set {
			if newValue
			{
				self.musicCon.audioController().mute()
			}
			else
			{
				self.musicCon.audioController().unmute()
			}
		}
	}

	var volume: Int {
		get { self.musicCon.audioController().getVolume() }
		set {
			self.musicCon.audioController().setVolume(volume: newValue)
		}
	}

	func getPlaybackState() -> PlaybackState
	{
		return self.isPlaying
			? .Playing(elapsed: self.musicCon.getElapsedTime())
			: .Paused(elapsed: self.musicCon.getElapsedTime())
	}


	func poke()
	{
		DispatchQueue.main.async {
			self.dummy.toggle()
		}
	}

	func spin()
	{
		DispatchQueue.main.async {
			withAnimation(.easeIn(duration: 0.35)) {
				self.spinning += 1
			}
		}
	}

	func unspin()
	{
		DispatchQueue.main.async {
			withAnimation(.easeOut(duration: 0.35)) {
				if self.spinning > 0 {
					self.spinning -= 1
				}
			}
		}
	}

	func subscribe(with: @escaping (Song?, PlaybackState) -> Void)
	{
		self.subscribers.append(with)
	}

	func setStatus(s: String, timeout: TimeInterval? = nil)
	{
		DispatchQueue.main.async {
			withAnimation(.easeIn(duration: 0.25)) {
				self.status = s
			}
		}

		if let t = timeout {
			// can't update the UI in background threads.
			DispatchQueue.main.asyncAfter(deadline: .now() + t) {
				withAnimation(.easeOut(duration: 0.45)) {
					self.status = ""
				}
			}
		}
	}

	public static func getDefaultAlbumArt() -> AnyView
	{
		return AnyView(
			Image(nsImage: #imageLiteral(resourceName: "NoCoverArt2"))
				.resizable()
				.saturation(0.85)
				.background(Rectangle().foregroundColor(Color(.sRGB, red: 0.114, green: 0.122, blue: 0.169)))
		)
	}

	func onSongChange(song: Song?)
	{
		// welcome to the land of toxicity.
		let animDuration = 0.3

		// the album art can be animated normally:
		DispatchQueue.main.async {
			withAnimation(.easeInOut(duration: animDuration)) {

				switch song?.isFavourite
				{
					case .Yes:
						self.favOpacity = 1.0

					case .PendingYes:
						self.favOpacity = 0.25

					case .PendingNo:
						self.favOpacity = 0.50

					default:
						self.favOpacity = 0.0
				}

				if let art = song?.album.1
				{
					self.albumArt = AnyView(Image(nsImage: art).resizable())
				}
				else
				{
					self.albumArt = Self.getDefaultAlbumArt()
				}
			}

			// the text must be animated manually, using opacity. only do this if the song is not the same.
			// since we are adjusting the opacity manually, SwiftUI cannot "optimise away" the animation if
			// the new value is the same as the old value.
			if let s = self.currentSong, s == song {
				return
			}

			self.currentSong = song
			for sub in self.subscribers {
				sub(self.currentSong, self.getPlaybackState())
			}

			withAnimation(.easeOut(duration: animDuration)) {
				self.textOpacity = 0

				DispatchQueue.main.asyncAfter(deadline: .now() + animDuration) {

					if let song = song
					{
						self.songTitle = song.title
						self.songArtist = song.artists.joined(separator: ", ")
					}
					else
					{
						self.songTitle = "not playing"
						self.songArtist = "—"
					}

					withAnimation(.easeIn(duration: animDuration)) {
						self.textOpacity = 1
					}
				}
			}
		}
	}

	func getCurrentSong() -> Song?
	{
		return self.currentSong
	}

	func controller() -> ServiceController
	{
		return self.musicCon
	}

	func set(controller: ServiceController)
	{
		self.musicCon = controller
	}

	init(backend: ServiceController.Type)
	{
		self.musicCon = backend.init(viewModel: self)
		self.onSongChange(song: nil)
	}
}





