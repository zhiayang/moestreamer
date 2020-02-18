// LocalAudioController.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Foundation
import AVFoundation

private extension MusicItem
{
	func toAVItem() -> AVPlayerItem
	{
		let ret = AVPlayerItem(url: self.url)
		return ret
	}
}

class LocalAudioController : NSObject, AudioController, AVAudioPlayerDelegate
{
	private var playing: Bool = false
	private var muted: Bool = Settings.get(.audioMuted())
	private var volume: Int = Settings.get(.audioVolume())

	private var currentAVItem: AVPlayerItem? = nil
	private var getNextSong: () -> MusicItem
	private var player: AVPlayer

	init(nextSongCallback: @escaping () -> MusicItem)
	{
		self.player = AVPlayer(playerItem: nil)
		self.getNextSong = nextSongCallback

		super.init()

		NotificationCenter.default.addObserver(self, selector: #selector(itemFinishedPlaying(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player.currentItem)
	}


	func play(item: MusicItem)
	{
		let av = item.toAVItem()
		self.player.replaceCurrentItem(with: av)
		self.currentAVItem = av

		self.player.play()
	}

	@objc func itemFinishedPlaying(_ notif: NSNotification)
	{
		self.play(item: self.getNextSong())
	}


	func setVolume(volume: Int)
	{
		let vol = volume < 0 ? 0 : volume > 100 ? 100 : volume

		if !self.muted {
			// only actually change the volume if we aren't muted.
			self.player.volume = Float(vol) / 100.0
		}

		self.volume = vol

		// also change the saved volume
		Settings.set(.audioVolume(), value: vol)
	}

	func getVolume() -> Int
	{
		return self.volume
	}

	func isMuted() -> Bool
	{
		return self.muted
	}

	func mute()
	{
		self.player.volume = 0
		self.muted = true

		Settings.set(.audioMuted(), value: true)
	}

	func unmute()
	{
		self.player.volume = Float(self.volume) / 100.0
		self.muted = false

		Settings.set(.audioMuted(), value: false)
	}

	func isPlaying() -> Bool
	{
		return self.playing
	}

	func play()
	{
		self.player.play()
		self.playing = true
	}

	func pause()
	{
		self.player.pause()
		self.playing = false
	}

	func stop()
	{
		self.player.replaceCurrentItem(with: nil)
		self.playing = false
	}

}
