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

	private var getNextSong: () -> MusicItem?
	private var engine: AudioEngine

	init(nextSongCallback: @escaping () -> MusicItem?)
	{
		self.engine = AudioEngine()
		self.getNextSong = nextSongCallback

		super.init()
		self.engine.prepare()
	}

	func enqueue(item: MusicItem)
	{
		self.engine.replaceCurrentItem(with: item, onComplete: { [weak self] in
			if let n = self?.getNextSong() {
				self?.enqueue(item: n)
			}
		})

		self.setVolume(volume: self.volume)

		// if we were paused before, don't play it.
		if self.playing {
			self.engine.play()
		}
	}

	func getElapsedTime() -> Double
	{
		return self.engine.getPlayerTime().clamped(from: 0, to: .infinity)
	}

	func setVolume(volume: Int)
	{
		self.volume = volume.clamped(from: 0, to: 100)
		Settings.set(.audioVolume(), value: self.volume)

		let scale: Int = Settings.get(.audioVolumeScale())
		let scaledVol = Double(self.volume * scale) / 100.0

		if !self.muted
		{
			// only actually change the volume if we aren't muted.
			var real = Double(scaledVol) / 100.0
			real = real.clamped(from: 0, to: 1)

			self.engine.setVolume(Float(real))
		}
		else
		{
			self.engine.setVolume(0)
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

	func isPlaying() -> Bool
	{
		return self.playing
	}

	func mute()
	{
		self.engine.setVolume(0)
		self.muted = true

		Settings.set(.audioMuted(), value: true)
	}

	func unmute()
	{
		self.muted = false
		self.setVolume(volume: self.volume)

		Settings.set(.audioMuted(), value: false)
	}

	func play()
	{
		self.engine.play()
		self.playing = true
	}

	func pause()
	{
		self.engine.pause()
		self.playing = false
	}

	func stop()
	{
		self.engine.stop()
		self.playing = false
	}

	func setPlaybackMirrorDevice(to device: AudioDevice)
	{
		if device == .none() {
			self.engine.unsetMirrorDevice()
		} else {
			self.engine.setMirrorDevice(device: device)
		}
	}

	func getPlaybackMirrorDevice() -> AudioDevice
	{
		return self.engine.getMirrorDevice()
	}
}

