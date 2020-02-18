// LocalMusicLibrary.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Foundation
import iTunesLibrary

struct MusicItem
{
	var song: Song
	var url: URL
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

	required init()
	{
		self.library = try! ITLibrary(apiVersion: "1.0")
		self.audioCon = LocalAudioController(nextSongCallback: self.getNextSong)

		// load the selected playlist from preferences.
		self.setCurrentPlaylist(playlist: Settings.get(.localMusicPlaylist()))
	}


	func getNextSong() -> MusicItem
	{
		self.currentIdx += 1
		if self.currentIdx == self.songs.count {
			self.songs = self.songs.shuffled()
			self.currentIdx = 0
		}

		let ret = self.songs[self.currentIdx]
		self.currentSong = ret

		Logger.log(msg: "song: \(ret.song.title)")
		self.viewModel?.onSongChange(song: ret.song)

		return ret
	}

	func refresh()
	{
		// nothing
	}

	func nextSong()
	{
		self.audioCon.play(item: self.getNextSong())
	}

	func start()
	{
		if self.currentSong != nil
		{
			self.audioCon.play()
		}
		else
		{
			self.audioCon.play(item: self.getNextSong())
		}
	}

	func pause()
	{
		// no-op
	}

	func stop()
	{
		// no-op
		self.audioCon.stop()
	}

	func toggleFavourite()
	{
		// no-op. idk how to access the favourite API for itunes
	}

	private func updateSongList()
	{
		if let pl = self.currentPlaylist {
			self.currentIdx = 0
			self.songs = pl.items
				.filter({ $0.location != nil })
				.filter({ !$0.isVideo })
				.map({
					MusicItem(song: Song(id: $0.location!.hashValue,
										 title: $0.title,
										 album: ($0.album.title, $0.artwork?.image),
										 artists: [ $0.artist?.name ?? "" ],
										 isFavourite: .No),
							  url: $0.location!)
				})
				.shuffled()
		}
		else
		{
			self.songs = [ ]
		}
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

			DispatchQueue.global().async {
				self.updateSongList()
			}
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
