// LocalMusicLibrary.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Foundation
import iTunesLibrary

// the only reason this is a class is so we can have reference semantics.
class MusicItem
{
	var song: Song
	var location: URL?
	var mediaItem: ITLibMediaItem

	var volumeMultiplier: Double = 1.0

	init(_ song: Song, at location: URL?, withMediaItem item: ITLibMediaItem, withVolumeScale mult: Double)
	{
		self.song = song
		self.location = location
		self.mediaItem = item
		self.volumeMultiplier = mult
	}
}

class LocalMusicController : ServiceController
{
	private var library: ITLibrary
	private var audioCon: LocalAudioController!

	private var viewModel: ViewModel? = nil

	private var currentPlaylist: ITLibPlaylist? = nil

	private var songs: [MusicItem] = [ ]
	private var currentIdx: Int = 0
	private var currentSong: MusicItem? = nil

//	private var nextSongGenerator: (
	private var shuffleBehaviour: ShuffleBehaviour

	// a bit hacky, but whatever.
	private var isWaitingForFirstSong = true

	required init(viewModel: ViewModel?)
	{
		self.library = try! ITLibrary(apiVersion: "1.0")
		self.shuffleBehaviour = Settings.getKE(.localMusicShuffle())
		self.viewModel = viewModel

		self.audioCon = LocalAudioController(nextSongCallback: self.getNextSong)

		// load the selected playlist from preferences.
		self.setCurrentPlaylist(playlist: Settings.get(.localMusicPlaylist()))
	}

	deinit
	{
		// not entirely sure if this is necessary...
		self.library.unloadData()
	}

	func isReady() -> Bool
	{
		return self.currentSong != nil && !self.isWaitingForFirstSong
	}

	func getNextSong() -> MusicItem?
	{
		self.currentIdx += 1
		
		if self.currentIdx == self.songs.count {
			self.songs = self.songs.shuffled()
			self.currentIdx = 0
		}

		if self.currentIdx < self.songs.count
		{
			while true
			{
				let ret = self.songs[self.currentIdx]
				if ret.mediaItem.location == nil || ret.mediaItem.isVideo {
					Logger.error("itunes", msg: "skipping invalid song \(ret.song.title)")
					self.currentIdx = (self.currentIdx + 1) % self.songs.count
					continue
				}

				ret.location = ret.mediaItem.location
				self.currentSong = ret
				break
			}

			let s = self.currentSong!
			Logger.log(msg: "song: \(s.song.title)")
			self.viewModel?.onSongChange(song: s.song)
			Statistics.instance.logSongPlayed()

			return s
		}
		else
		{
			return nil
		}
	}

	func refresh()
	{
		// nothing
	}

	func nextSong()
	{
		if let n = self.getNextSong() {
			self.audioCon.enqueue(item: n)
		}
	}

	func start()
	{
		if self.currentSong == nil
		{
			// this one only sets the song
			if let n = self.getNextSong() {
				self.audioCon.enqueue(item: n)
			}
		}
	}

	func pause()
	{
		// no-op
	}

	func stop()
	{
		self.audioCon.stop()
	}

	func toggleFavourite()
	{
		// no-op. idk how to access the favourite API for itunes
	}

	private func updateSongList()
	{
		// var count = 0
		func make_music_item(from item: ITLibMediaItem) -> MusicItem
		{
			// first, calculate the volume adjustment.
			// according to iTunesDB:
			// X = 1000 * 10 ^ (-0.1 * Y) where Y is the adjustment value in dB
			// and X is the value that goes into the SoundCheck field

			// so, `volumeNormalizationEnergy` is the SoundCheck field, and the adjustment in dB is
			let sc = Double(item.volumeNormalizationEnergy)
			let dbAdjust = log10(sc / 1000) / (-0.1)

			// next, we need to convert from dB to percentage multiplier.
			// a -3dB = 0.5, -6dB = 0.25, etc. this is simple, it's just 10^(dB/10)
			let volMult = pow(10, dbAdjust / 10)

			// we're setting the album art to nil and loading it in a separate thread, so we
			// can return from this function ASAP and present something usable (ie. the song title)
			let song = Song(id: item.persistentID.intValue,
							title: item.title,
							album: (item.album.title, nil),
							artists: [ item.artist?.name ?? "" ],
							isFavourite: .No)

			// we also don't init the location, because otherwise it becomes super damn slow,
			// probably due to checking that the files exist on disk ):
			return MusicItem(song, at: nil, withMediaItem: item, withVolumeScale: volMult)
		}

		if let pl = self.currentPlaylist {
			self.currentIdx = 0

			Logger.log("itunes", msg: "using playlist \(pl.name)")

			self.viewModel?.spin()
			DispatchQueue.global().async {

				let base = pl.items.map(make_music_item)
				switch(self.shuffleBehaviour)
				{
					case .None:
						self.songs = base

					case .Random:
						self.songs = base.shuffled()

					case .Oldest:
						self.songs = base.sorted(by: {
							let a = $0.mediaItem.lastPlayedDate ?? .distantPast
							let b = $1.mediaItem.lastPlayedDate ?? .distantPast

							return a < b
						})

					case .LeastPlayed:
						// because we expect more than one song to have the same play count
						// (eg: 0 or 1), we group by play count first, then shuffle those.
						let grouped = Dictionary(grouping: base, by: { $0.mediaItem.playCount })
						self.songs = grouped.values.flatMap({ $0 })
				}

				// spin up a background task to fetch the images for each item in the queue.
				DispatchQueue.global().async {
					self.songs.forEach({
						$0.song.album.1 = $0.mediaItem.artwork?.image
					})

					if self.isWaitingForFirstSong
					{
						let ns = self.getNextSong()
						if let s = ns {
							self.audioCon.enqueue(item: s)
							self.currentSong = s
						}

						// load the current song up
						self.viewModel?.onSongChange(song: ns?.song)

						// this tells the rest of the system that we're done with setup.
						self.isWaitingForFirstSong = false
					}

					Logger.log("itunes", msg: "loaded \(self.songs.count) songs from playlist \(pl.name)")
					self.viewModel?.unspin()
				}
			}
		}
		else
		{
			self.songs = [ ]
		}
	}






	func setShuffleBehaviour(as behaviour: ShuffleBehaviour)
	{
		self.shuffleBehaviour = behaviour
		DispatchQueue.global().async {
			self.updateSongList()
		}
	}

	func getShuffleBehaviour() -> ShuffleBehaviour
	{
		return self.shuffleBehaviour
	}

	func getCurrentPlaylist() -> String
	{
		return self.currentPlaylist?.name ?? ""
	}

	func setCurrentPlaylist(playlist: String)
	{
		if let pl = self.library.allPlaylists.first(where: { playlist == $0.name })
		{
			self.currentPlaylist = pl
			self.isWaitingForFirstSong = true
			self.updateSongList()
		}
		else
		{
			Logger.error("itunes", msg: "invalid playlist \(playlist)")
		}
	}

	func getAllPlaylists() -> [String]
	{
		return self.library.allPlaylists
			.filter({ $0.isVisible })
			// distinguishedKind is probably the "special" playlist. so checking == none means normal playlists.
			.filter({ $0.distinguishedKind == .kindNone })
			.map({ $0.name })
	}

	func getCurrentSong() -> Song?
	{
		return self.currentSong?.song
	}

	func audioController() -> AudioController
	{
		return self.audioCon
	}

	func getCapabilities() -> ServiceCapabilities
	{
		return [ .nextTrack ]
	}

	func setViewModel(viewModel: ViewModel)
	{
		self.viewModel = viewModel
	}

	func getViewModel() -> ViewModel?
	{
		return self.viewModel
	}
}
