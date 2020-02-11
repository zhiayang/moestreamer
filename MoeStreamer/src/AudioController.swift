// AudioController.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import VLCKit
import Foundation

class AudioController
{
	private var muted: Bool = Settings.get(.audioMuted())
	private var volume: Int = Settings.get(.audioVolume())

	private let pauseable: Bool
	private let vlcMP = VLCMediaPlayer()

	init(url: URL, pauseable: Bool)
	{
		self.vlcMP.media = VLCMedia(url: url)
		self.vlcMP.audio.volume = Int32(self.volume)

		self.pauseable = pauseable
	}

	func setVolume(volume: Int)
	{
		let vol = volume < 0 ? 0 : volume > 100 ? 100 : volume

		if !self.muted {
			// only actually change the volume if we aren't muted.
			self.vlcMP.audio.volume = Int32(vol)
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

	func toggleMute()
	{
		if self.muted { self.unmute() }
		else          { self.mute() }
	}

	func mute()
	{
		self.vlcMP.audio.volume = 0
		self.muted = true

		Settings.set(.audioMuted(), value: true)
	}

	func unmute()
	{
		self.vlcMP.audio.volume = Int32(self.volume)
		self.muted = false

		Settings.set(.audioMuted(), value: false)
	}

	func isPlaying() -> Bool
	{
		return self.vlcMP.isPlaying
	}

	func togglePlay()
	{
		if self.isPlaying() {
			self.pause()
		} else {
			self.play()
		}
	}

	func play()
	{
		self.vlcMP.play()
	}

	func pause()
	{
		self.pauseable ? self.vlcMP.pause() : self.vlcMP.stop()
	}

	func stop()
	{
		self.vlcMP.stop()
	}
}
