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

	init(_ song: Song, withMediaItem item: ITLibMediaItem)
	{
		self.song = song
		self.mediaItem = item

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

	private var manualQueueIndex: Int = 0
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

	private func updateCurrentSong(_ song: MusicItem) -> MusicItem
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
		if self.manualQueueIndex < self.manuallyQueuedSongs.count
		{
			defer { self.manualQueueIndex += 1 }
			return self.updateCurrentSong(self.manuallyQueuedSongs[self.manualQueueIndex])
		}
		else
		{
			// reset once we exhaust the queue, so the list doesn't grow infinitely long
			self.manualQueueIndex = 0
			self.manuallyQueuedSongs = [ ]
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

				return self.updateCurrentSong(ret)
			}
		}
		else
		{
			return nil
		}
	}

	func searchSongs(name: String, inProgress: ((Song) -> Void)?, onComplete: @escaping () -> Void)
	{
		let name = name.trimmingCharacters(in: .whitespaces)
		if name.isEmpty
		{
			onComplete()

			return
		}

		DispatchQueue.global().async {

			Logger.log(msg: "searching for: \(name)")
			let searchWords = name.words.map({ $0.lowercased() })

			var found = 0

			// i don't believe swift's map/filter are lazy, so just use a for loop
			// so we can append iteratively.
			for song in self.songs
			{
				let titleWords = song.song.title.words.map({ $0.lowercased() })
				if searchWords.allSatisfy({ word -> Bool in
					titleWords.contains(where: { $0.hasPrefix(word) })
				}) {
					inProgress?(song.song)
					found += 1
				}
			}

			Logger.log(msg: "search: found \(found) song\(found == 1 ? "" : "s")")
			onComplete()
		}
	}

	func enqueueSong(_ song: Song, immediately: Bool)
	{
		if let item = self.songsById[song.id] {

			if immediately
			{
				self.manualQueueIndex = 0
				self.manuallyQueuedSongs.insert(item, at: 0)
				self.nextSong()
			}
			else
			{
				self.manuallyQueuedSongs.append(item)
				let msg = "queued: \(song.title)"
			
				Logger.log(msg: msg)
				self.viewModel?.setStatus(s: msg, timeout: 1.5)
			}
		}
	}

	func refresh()
	{
		// just refresh the playlist.
		self.viewModel?.spin()
		self.updateSongList()
		self.viewModel?.unspin()
	}

	func nextSong()
	{
		if let n = self.getNextSong() {
			self.audioCon.enqueue(item: n)
		}
	}

	func previousSong()
	{
		// the threshold is 4 seconds, for now.
		if self.audioCon.getElapsedTime() > 4.0
		{
			// just rewind the current song, instead of going to the previous song.
			if let s = self.currentSong {
				self.audioCon.enqueue(item: s)
			}
		}
		else
		{
			if self.manualQueueIndex > 0
			{
				self.manualQueueIndex -= 1
				if let s = self.getNextSong() {
					self.audioCon.enqueue(item: s)
				}
			}
			else if self.currentIdx > 0
			{
				self.currentIdx -= 1
				self.audioCon.enqueue(item: self.updateCurrentSong(self.songs[self.currentIdx]))
			}
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
			// we're setting the album art to nil and loading it in a separate thread, so we
			// can return from this function ASAP and present something usable (ie. the song title)
			let song = Song(id: item.persistentID.intValue,
							title: item.title,
							album: (item.album.title, nil),
							artists: [ item.artist?.name ?? "" ],
							isFavourite: .No,
							duration: Double(item.totalTime) / 1000.0)

			return MusicItem(song, withMediaItem: item)
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

				self.songs.forEach { (item: MusicItem) in
					self.songsById[item.song.id] = item
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

	func getElapsedTime() -> Double
	{
		return self.audioCon.getElapsedTime()
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
		return [ .nextTrack, .searchTracks, .timeInfo ]
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
