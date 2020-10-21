// LocalAudioController.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Foundation
import AVFoundation

private extension MusicItem
{
	func toAVItem() -> AVPlayerItem
	{
		let ret = AVPlayerItem(url: self.mediaItem.location!)
		return ret
	}
}

private extension Comparable
{
	func clamped(from min: Self, to max: Self) -> Self
	{
		return (self < min ? min : (self > max ? max : self))
	}
}

class LocalAudioController : NSObject, AudioController, AVAudioPlayerDelegate
{
	private var playing: Bool = false
	private var muted: Bool = Settings.get(.audioMuted())
	private var volume: Int = Settings.get(.audioVolume())

	private var currentItem: MusicItem? = nil
	private var getNextSong: () -> MusicItem?
	private var player: AVPlayer

	init(nextSongCallback: @escaping () -> MusicItem?)
	{
		self.player = AVPlayer(playerItem: nil)
		self.getNextSong = nextSongCallback

		super.init()

		NotificationCenter.default.addObserver(self, selector: #selector(itemFinishedPlaying(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player.currentItem)
	}


	func enqueue(item: MusicItem)
	{
		let av = item.toAVItem()
		self.player.replaceCurrentItem(with: av)
		self.currentItem = item

		self.setVolume(volume: self.volume)

		// if we were paused before, don't play it.
		if self.playing {
			self.player.play()
		}
	}

	@objc func itemFinishedPlaying(_ notif: NSNotification)
	{
		if let n = self.getNextSong() {
			self.enqueue(item: n)
		}
	}


	func setVolume(volume: Int)
	{
		self.volume = volume.clamped(from: 0, to: 100)
		Settings.set(.audioVolume(), value: self.volume)

		let multiplier: Double
		if Settings.get(.audioNormaliseVolume()) {
			multiplier = self.currentItem?.volumeMultiplier ?? 1.0
		} else {
			multiplier = 1
		}

		if !self.muted
		{
			// only actually change the volume if we aren't muted.
			var real: Double = (Double(self.volume) / 100.0) * multiplier
			real = real.clamped(from: 0, to: 1)

			self.player.volume = Float(real)
		}
		else
		{
			self.player.volume = 0
		}
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
		self.muted = false
		self.setVolume(volume: self.volume)

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
