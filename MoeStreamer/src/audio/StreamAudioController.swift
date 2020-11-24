// AudioController.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import VLCKit
import Foundation

class StreamAudioController : NSObject, AudioController, VLCMediaPlayerDelegate
{
	private var muted: Bool = Settings.get(.audioMuted())
	private var volume: Int = Settings.get(.audioVolume())
	private var streamBuffer: Int = Settings.get(.streamBufferMs())

	private var stopped = true

	private let pauseable: Bool
	private let streamUrl: URL
	private let vlcMP: VLCMediaPlayer

	init(url: URL, pauseable: Bool)
	{
		self.vlcMP = VLCMediaPlayer()
		self.pauseable = pauseable
		self.streamUrl = url;

		super.init()

		self.vlcMP.delegate = self
		self.reset()
	}

	private func reset()
	{
		self.vlcMP.media = VLCMedia(url: self.streamUrl)
		self.vlcMP.media.addOptions([ "network-caching": self.streamBuffer ])

		self.vlcMP.audio.volume = self.muted ? 0 : Int32(self.volume)

		self.stopped = false
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

	func play()
	{
		if self.stopped {
			self.reset()
		}
		
		self.vlcMP.play()
	}

	func pause()
	{
		self.pauseable ? self.vlcMP.pause() : self.vlcMP.stop()
	}

	func stop()
	{
		self.stopped = true
		self.vlcMP.stop()
	}



	func mediaPlayerStateChanged(_ notif: Notification!)
	{
		switch self.vlcMP.state
		{
			case .buffering:
				Logger.log("audio", msg: "unexpected buffering")

			case .error:
				Logger.error("audio", msg: "stream error")
				self.reset()

			case .ended:
				Logger.error("audio", msg: "unexpected end of stream")
				self.reset()

			default:
				break
		}
	}
}
