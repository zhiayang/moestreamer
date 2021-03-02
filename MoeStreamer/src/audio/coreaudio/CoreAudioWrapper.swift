// CoreAudioWrapper.swift
// Copyright (c) 2021, zhiayang
// Licensed under the Apache License Version 2.0.

import CoreAudio
import Foundation

struct CoreAudioWrapper
{
	static func getProperty<T>(sel: AudioObjectPropertySelector,
							   id: AudioObjectID = AudioObjectID(kAudioObjectSystemObject),
							   scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
							   element: AudioObjectPropertyElement = kAudioObjectPropertyElementMaster,
							   value: UnsafeMutablePointer<T>,
							   size: UInt32? = nil) -> Bool
	{
		var propertySize: UInt32
		if let size = size {
			propertySize = size
		} else {
			guard let tmp = getPropertySize(sel: sel, id: id, scope: scope, element: element) else {
				return false
			}

			propertySize = tmp
		}

		var address = AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: element)
		let result = AudioObjectGetPropertyData(id, &address, 0, nil, &propertySize, value);

		guard result == 0 else {
			Logger.error(msg: "error from AudioObjectGetPropertyData: \(result)")
			return false
		}

		return true
	}

	static func setProperty<T>(sel: AudioObjectPropertySelector,
							id: AudioObjectID = AudioObjectID(kAudioObjectSystemObject),
							scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
							element: AudioObjectPropertyElement = kAudioObjectPropertyElementMaster,
							value: UnsafeMutablePointer<T>) -> Bool
	{
		var address = AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: element)
		let result = AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<T>.size), value);

		guard result == 0 else {
			Logger.error(msg: "error from AudioObjectSetPropertyData: \(result)")
			return false
		}

		return true
	}

	static func getPropertySize(sel: AudioObjectPropertySelector,
								id: AudioObjectID = AudioObjectID(kAudioObjectSystemObject),
								scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
								element: AudioObjectPropertyElement = kAudioObjectPropertyElementMaster) -> UInt32?
	{
		var propertySize: UInt32 = 0
		var address = AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: element)
		let result = AudioObjectGetPropertyDataSize(id, &address,
													UInt32(MemoryLayout<AudioObjectPropertyAddress>.size),
													nil, &propertySize)

		guard result == 0 else {
			Logger.error(msg: "error from AudioObjectGetPropertyDataSize: \(result)")
			return nil
		}

		return propertySize
	}
}

class CoreAudioDeviceWrapper
{
	var audioDeviceID: AudioDeviceID

	init(deviceID: AudioDeviceID)
	{
		self.audioDeviceID = deviceID
	}

	var hasOutput: Bool {
		get {
			var address = AudioObjectPropertyAddress(mSelector: AudioObjectPropertySelector(kAudioDevicePropertyStreamConfiguration),
													 mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
													 mElement: 0)

			var propsize  = UInt32(MemoryLayout<CFString?>.size)
			var result = AudioObjectGetPropertyDataSize(self.audioDeviceID, &address, 0, nil, &propsize)
			guard result == 0 else {
				return false
			}

			let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(propsize))
			result = AudioObjectGetPropertyData(self.audioDeviceID, &address, 0, nil, &propsize, bufferList);
			defer {
				bufferList.deallocate()
			}

			guard result == 0 else {
				return false
			}

			let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
			for bufferNum in 0 ..< buffers.count
			{
				if buffers[bufferNum].mNumberChannels > 0
				{
					return true
				}
			}

			return false
		}
	}

	var uid: String? {
		get {
			var address = AudioObjectPropertyAddress(mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceUID),
													 mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
													 mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))

			var name: CFString? = nil
			var propsize = UInt32(MemoryLayout<CFString?>.size)
			let result = AudioObjectGetPropertyData(self.audioDeviceID, &address, 0, nil, &propsize, &name)
			return result == 0
				? (name as String?)
				: nil
		}
	}

	var name: String? {
		get {
			var address = AudioObjectPropertyAddress(mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceNameCFString),
													 mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
													 mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))

			var name: CFString? = nil
			var propsize = UInt32(MemoryLayout<CFString?>.size)
			let result = AudioObjectGetPropertyData(self.audioDeviceID, &address, 0, nil, &propsize, &name)
			return result == 0
				? (name as String?)
				: nil
		}
	}
}
