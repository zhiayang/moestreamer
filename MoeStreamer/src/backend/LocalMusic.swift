// LocalMusicLibrary.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import SwiftUI
import Foundation
import iTunesLibrary

extension StringProtocol
{
	var words: [SubSequence] { components(separated: .byWords) }

	func components(separated options: String.EnumerationOptions)-> [SubSequence] {
		var components: [SubSequence] = []
		enumerateSubstrings(in: startIndex..., options: options) { _, range, _, _ in
			components.append(self[range])
		}
		return components
	}
}

// the only reason this is a class is so we can have reference semantics.
class MusicItem
{
	var songTitle: String
	var song: Song
	var mediaItem: ITLibMediaItem

	var volumeMultiplier: Double = 1.0

	init(_ song: Song, withMediaItem item: ITLibMediaItem, withVolumeScale mult: Double)
	{
		self.song = song
		self.mediaItem = item
		self.volumeMultiplier = mult

		self.songTitle = song.title
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

	// oof
	private var songsById: [Int: MusicItem] = [:]

	private var manuallyQueuedSongs: [MusicItem] = [ ]

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

	private func changeSong(_ song: MusicItem) -> MusicItem
	{
		self.currentSong = song

		let s = self.currentSong!
		Logger.log(msg: "song: \(s.song.title)")
		self.viewModel?.onSongChange(song: s.song)
		Statistics.instance.logSongPlayed()

		return s
	}

	func getNextSong() -> MusicItem?
	{
		if !self.manuallyQueuedSongs.isEmpty
		{
			defer { self.manuallyQueuedSongs.remove(at: 0) }
			let song = self.manuallyQueuedSongs.first!

			return self.changeSong(song)
		}

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

				return self.changeSong(ret)
			}
		}
		else
		{
			return nil
		}
	}

	// TODO: search songs asynchronously
//	func searchSongs(name: String) -> [Song]
//	{
//		let searchWords = name.words.map({ $0.lowercased() })
//
//		return self.songs.filter { (item: MusicItem) -> Bool in
//
//			let titleWords = item.song.title.words.map({ $0.lowercased() })
//			return searchWords.allSatisfy { (word: String) -> Bool in
//				titleWords.contains(where: { $0.hasPrefix(word) })
//			}
//
//		}.map { $0.song }
//	}

	func searchSongs(name: String, into: Binding<[Song]>, onComplete: @escaping () -> Void)
	{
		if name.isEmpty
		{
			into.wrappedValue = []
			onComplete()

			return
		}

		DispatchQueue.global().async {

			Logger.log(msg: "searching for: \(name)")
			let searchWords = name.words.map({ $0.lowercased() })

			// i don't believe swift's map/filter are lazy, so just use a for loop
			// so we can append iteratively.
			for song in self.songs
			{
				let titleWords = song.song.title.words.map({ $0.lowercased() })
				if searchWords.allSatisfy({ word -> Bool in
					titleWords.contains(where: { $0.hasPrefix(word) })
				}) {
					into.wrappedValue.append(song.song)
				}
			}

			Logger.log(msg: "search: found \(into.wrappedValue.count) song\(into.wrappedValue.count == 1 ? "" : "s")")
			onComplete()
		}
	}

	func setNextSong(_ song: Song, immediately: Bool)
	{
		if let item = self.songsById[song.id] {

			Logger.log(msg: "queued: \(song.title)")

			if immediately
			{
				self.manuallyQueuedSongs.insert(item, at: 0)
				self.nextSong()
			}
			else
			{
				self.manuallyQueuedSongs.append(item)
			}
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

			return MusicItem(song, withMediaItem: item, withVolumeScale: volMult)
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

				self.songs.forEach { (item: MusicItem) in
					self.songsById[item.song.id] = item
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
		return [ .nextTrack, .searchTracks ]
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
