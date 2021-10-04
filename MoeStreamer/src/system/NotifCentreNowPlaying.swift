// MediaKeyHandler.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import MediaPlayer
import Foundation

class NowPlayingCentre : NSObject
{
	private var controller: ServiceController!
	private var currentSong: Song? = nil

	init(controller: ServiceController)
	{
		super.init()
		self.controller = controller
		self.activateMPRemote()
		self.updateMediaCentre(with: nil, state: .Paused(elapsed: 0))
	}

	deinit
	{
		self.deactivateMPRemote()
	}

	@objc func handleEvent(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus
	{
		guard let vm = self.controller.getViewModel() as? MainModel else {
			return .success
		}

		let remote = MPRemoteCommandCenter.shared()

		switch event.command {
			case remote.playCommand:
				vm.isPlaying = true

			case remote.pauseCommand:
				vm.isPlaying = false

			case remote.togglePlayPauseCommand:
				vm.isPlaying.toggle()

			case remote.nextTrackCommand:
				vm.controller().nextSong()

			case remote.previousTrackCommand:
				vm.controller().previousSong()

			default:
				break
		}
		vm.poke()
		return .success
	}

	private func activateMPRemote()
	{
		let remote = MPRemoteCommandCenter.shared()
		remote.playCommand.isEnabled = true
		remote.playCommand.addTarget(self, action: #selector(handleEvent))

		remote.pauseCommand.isEnabled = true
		remote.pauseCommand.addTarget(self, action: #selector(handleEvent))

		remote.togglePlayPauseCommand.isEnabled = true
		remote.togglePlayPauseCommand.addTarget(self, action: #selector(handleEvent))

		remote.previousTrackCommand.isEnabled = true
		remote.previousTrackCommand.addTarget(self, action: #selector(handleEvent))

		remote.nextTrackCommand.isEnabled = true
		remote.nextTrackCommand.addTarget(self, action: #selector(handleEvent))
		MPNowPlayingInfoCenter.default().playbackState = .paused
	}

	private func deactivateMPRemote()
	{
		let remote = MPRemoteCommandCenter.shared()

		remote.playCommand.removeTarget(self)
		remote.pauseCommand.removeTarget(self)
		remote.nextTrackCommand.removeTarget(self)
		remote.previousTrackCommand.removeTarget(self)
		remote.togglePlayPauseCommand.removeTarget(self)

		MPNowPlayingInfoCenter.default().playbackState = .stopped
	}

	private func getMetadata(for song: Song, state: PlaybackState) -> [String: Any]
	{
		var ret = [String: Any]()

		ret[MPMediaItemPropertyTitle] = song.title
		ret[MPMediaItemPropertyArtist] = song.artists.joined(separator: ", ")
		ret[MPMediaItemPropertyPlaybackDuration] = song.duration
		ret[MPNowPlayingInfoPropertyPlaybackRate] = 1
		ret[MPNowPlayingInfoPropertyElapsedPlaybackTime] = state.elapsed

		guard let art = song.album.1 else {
			ret[MPMediaItemPropertyArtwork] = nil
			return ret
		}
//		ret[MPMediaItemPropertyArtwork] = nil
		let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: art.size.width, height: art.size.height),
										 requestHandler: { [weak art] _ in return art ?? #imageLiteral(resourceName: "NoCoverArt2") })

		ret[MPMediaItemPropertyArtwork] = artwork

		return ret
	}

	func updateMediaCentre(with song: Song?, state: PlaybackState)
	{
		guard let song = song else {
			return
		}


		MPNowPlayingInfoCenter.default().nowPlayingInfo = self.getMetadata(for: song, state: state)
		MPNowPlayingInfoCenter.default().playbackState = (state.playing ? .playing : .paused)
	}
}
