// AudioEngine.swift
// Copyright (c) 2021, zhiayang
// Licensed under the Apache License Version 2.0.

import Foundation
import AVFoundation

class AudioEngine
{
	private var e1: AVAudioEngine
	private var e2: AVAudioEngine

	private var p1: AVAudioPlayerNode
	private var p2: AVAudioPlayerNode

	private var mirrorDevice: AudioDevice
	private var savedElapsedTime: Double = 0

	// super thread unsafe
	private var didStopPlayer: Bool = false

	init()
	{
		self.e1 = AVAudioEngine()
		self.e2 = AVAudioEngine()

		self.p1 = AVAudioPlayerNode()
		self.p2 = AVAudioPlayerNode()

		self.mirrorDevice = .none()

		self.e1.attach(self.p1)
		self.e1.connect(self.p1, to: self.e1.mainMixerNode, format: nil)
		self.e1.connect(self.e1.mainMixerNode, to: self.e1.outputNode, format: nil)

		self.e2.attach(self.p2)
		self.e2.connect(self.p2, to: self.e2.mainMixerNode, format: nil)
		self.e2.connect(self.e2.mainMixerNode, to: self.e2.outputNode, format: nil)
	}

	func getPlayerTime() -> Double
	{
		return self.p1.isPlaying
			? self.p1.currentTime
			: self.savedElapsedTime
	}

	func setVolume(_ volume: Float)
	{
		self.e1.mainMixerNode.outputVolume = volume
		self.e2.mainMixerNode.outputVolume = volume
	}

	func replaceCurrentItem(with item: MusicItem, onComplete: @escaping () -> Void)
	{
		guard let file = try? AVAudioFile(forReading: item.mediaItem.location!) else {
			Logger.error(msg: "failed to open file for song: \(item.songTitle)")
			return
		}

		if self.p1.isPlaying
		{
			self.didStopPlayer = true
			self.p1.stop()
		}

		self.p1.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack, completionHandler: { [weak self] _ in
			if self?.didStopPlayer ?? true {
				return
			}

			DispatchQueue.main.async {
				// since onComplete probably ends up calling this function itself, we have to do it from
				// a separate thread, since apparently calling stop() from inside this handler causes a deadlock
				onComplete()
			}
		})

		if self.didStopPlayer
		{
			self.didStopPlayer = false
			self.p1.play()
		}
	}

	func stop()
	{
		self.p1.stop()
		self.p2.stop()

		self.e1.stop()
		self.e2.stop()
	}

	func play()
	{
		try! self.e1.start()
		self.p1.play()

		if self.mirrorDevice != .none()
		{
			try! self.e2.start()
			self.p2.play()
		}
	}

	func pause()
	{
		self.savedElapsedTime = self.p1.currentTime

		self.p1.pause()
		self.p2.pause()

		self.e1.pause()
		self.e2.pause()
	}

	func prepare()
	{
		self.e1.prepare()
		self.e2.prepare()

		do {
			try self.e1.start()
			self.p1.pause()
			Logger.log(msg: "started audio engine")
		} catch {
			Logger.error(msg: "failed to start primary audio engine")
			return
		}
	}

	func setMirrorDevice(device: AudioDevice)
	{
		self.p1.removeTap(onBus: 0)
		self.p1.installTap(onBus: 0, bufferSize: 1024, format: nil, block: { (buffer, _) in
			self.p2.scheduleBuffer(buffer, completionHandler: nil)
		})

		try! self.e1.outputNode.auAudioUnit.setDeviceID(device.dev)

		self.mirrorDevice = device
		if self.p1.isPlaying
		{
			self.pause()

			// this delay is necessary for some reason. if not, then nothing will play.
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
				self.play()
			}
		}
	}

	func unsetMirrorDevice()
	{
		self.mirrorDevice = .none()
		self.e1.outputNode.removeTap(onBus: 0)
		self.e2.stop()
	}

	func getMirrorDevice() -> AudioDevice
	{
		return self.mirrorDevice
	}
}
