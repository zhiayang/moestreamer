// AudioController.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import VLCKit
import Foundation

class AudioController : ObservableObject
{
	@Published private var muted = Settings.get(key: "muted", default: false)
	private var oldVolume: Int32 = 0

	private let pauseable: Bool
	private let vlcMP = VLCMediaPlayer()

	init(url: URL, pauseable: Bool)
	{
		self.vlcMP.media = VLCMedia(url: url)
		self.pauseable = pauseable
	}

	func setVolume(volume: Int)
	{
		let vol = volume < 0 ? 0 : volume > 100 ? 100 : volume

		if !self.muted {
			// only actually change the volume if we aren't muted.
			self.vlcMP.audio.volume = Int32(vol)
		}

		self.oldVolume = Int32(vol)

		// also change the saved volume
		Settings.set(key: "volume", value: Double(vol))
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
		self.oldVolume = self.vlcMP.audio.volume
		self.vlcMP.audio.volume = 0
		self.muted = true

		Settings.set(key: "muted", value: true)
	}

	func unmute()
	{
		self.vlcMP.audio.volume = self.oldVolume
		self.muted = false

		Settings.set(key: "muted", value: false)
	}

	func play()
	{
		vlcMP.play()
	}

	func pause()
	{
		self.pauseable ? vlcMP.pause() : vlcMP.stop()
	}

	func stop()
	{
		vlcMP.stop()
	}
}
