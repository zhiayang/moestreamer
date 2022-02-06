// AudioController.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import VLCKit
import Foundation

class StreamAudioController : NSObject, AudioController, VLCMediaPlayerDelegate
{
	private var muted: Bool = Settings.get(.audioMuted())
	private var streamBuffer: Int = Settings.get(.streamBufferMs())

	private var stopped = true
	private var volume: Int = Settings.get(.audioVolume())

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

		let vol: Int = Settings.get(.audioVolume())
		self.vlcMP.audio.volume = self.muted ? 0 : Int32(vol)

		self.stopped = false
	}

	func setVolume(volume: Int)
	{
		self.volume = volume.clamped(from: 0, to: 100)
		Settings.set(.audioVolume(), value: self.volume)

		let scale: Int = Settings.get(.audioVolumeScale())
		let scaledVol = Double(self.volume * scale) / 100.0

		if !self.muted {
			// only actually change the volume if we aren't muted.
			self.vlcMP.audio.volume = Int32(scaledVol)
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
		self.muted = true
		self.vlcMP.audio.volume = 0

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

	func setPlaybackMirrorDevice(to: AudioDevice)
	{
	}

	func getPlaybackMirrorDevice() -> AudioDevice
	{
		return .none()
	}
}
