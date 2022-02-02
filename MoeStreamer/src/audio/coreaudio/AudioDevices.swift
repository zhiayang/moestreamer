// AudioDevices.swift
// Copyright (c) 2021, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import CoreAudio
import Foundation
import AVFoundation

class AudioDeviceManager
{
	static func getAudioDevices() -> [AudioDevice]
	{
		return [ AudioDevice.none() ] + getOutputDevices()
	}
}

fileprivate func getOutputDevices() -> [AudioDevice]
{
	guard let propertySize = CoreAudioWrapper.getPropertySize(sel: AudioObjectPropertySelector(kAudioHardwarePropertyDevices)) else {
		return [ ]
	}

	let numDevices = Int(propertySize / UInt32(MemoryLayout<AudioDeviceID>.size))
	var deviceIds = [AudioDeviceID](repeating: AudioDeviceID(), count: numDevices)

	guard CoreAudioWrapper.getProperty(sel: AudioObjectPropertySelector(kAudioHardwarePropertyDevices),
									   value: &deviceIds, size: propertySize)
	else {
		return [ ]
	}


	var systemDefOutputId = AudioDeviceID()
	guard CoreAudioWrapper.getProperty(sel: AudioObjectPropertySelector(kAudioHardwarePropertyDefaultSystemOutputDevice),
									   value: &systemDefOutputId) else {
		Logger.error(msg: "could not get default system output")
		return [ ]
	}

	let systemDevice = CoreAudioDeviceWrapper(deviceID: systemDefOutputId)

	return deviceIds
		.map({ CoreAudioDeviceWrapper(deviceID: $0) })
		.filter({ $0.name != nil && $0.uid != nil && $0.uid != systemDevice.uid && $0.hasOutput })
		.filter({ !$0.name!.starts(with: "CADefaultDeviceAggregate") })
		.map({ AudioDevice(uid: $0.uid!, dev: $0.audioDeviceID, name: $0.name!) })
}


struct AudioDevice : CustomStringConvertible, Hashable, Equatable
{
	let uid: String?
	let dev: AudioDeviceID
	let name: String

	var description: String { return name }

	static func none() -> AudioDevice
	{
		return AudioDevice(uid: nil, dev: AudioDeviceID(), name: "none")
	}
}


extension AVAudioPlayerNode
{
	var currentTime: TimeInterval {
		get {
			if let nodeTime = self.lastRenderTime, let playerTime = self.playerTime(forNodeTime: nodeTime) {
				return Double(playerTime.sampleTime) / playerTime.sampleRate
			}

			return 0
		}
	}
}
