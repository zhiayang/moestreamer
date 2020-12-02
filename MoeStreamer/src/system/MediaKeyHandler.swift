// MediaKeyHandler.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import Foundation
import MediaPlayer

var globalMediaKeyHandler = MediaKeyHandler()

class MediaKeyHandler : NSObject
{
	fileprivate var enabled: Bool = false
	fileprivate var eventTap: CFMachPort! = nil
	fileprivate var controller: ServiceController? = nil
	fileprivate var runLoopSource: CFRunLoopSource! = nil

	override init()
	{
		super.init()
	}

	private func setup()
	{
		let tap_ = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
									 eventsOfInterest: CGEventMask(NX_SYSDEFINEDMASK),
									 callback: handlerCallback, userInfo: Unmanaged.passUnretained(self).toOpaque())

		if tap_ == nil
		{
			Logger.error(msg: "failed to setup media keys")
			return
		}

		self.eventTap = tap_!

		runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.eventTap, 0)
		CFRunLoopAddSource(CFRunLoopGetCurrent(), self.runLoopSource, .commonModes)

		CGEvent.tapEnable(tap: self.eventTap, enable: true)
		enabled = true

		Logger.log(msg: "media keys enabled")
	}

	private func destroy()
	{
		if self.enabled
		{
			self.enabled = false

			CGEvent.tapEnable(tap: self.eventTap, enable: false)
			CFRunLoopRemoveSource(CFRunLoopGetMain(), self.runLoopSource, .commonModes)
			CFMachPortInvalidate(self.eventTap)

			Logger.log(msg: "media keys ignored")
		}
	}

	func setController(_ con: ServiceController)
	{
		self.controller = con
	}

	func enable(_ enable: Bool, musicCon: ServiceController)
	{
		self.setController(musicCon)

		enable ? self.setup()
			   : self.destroy()
	}
}

fileprivate func handlerCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
								 refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>?
{
	guard let obj = refcon else {
		return Unmanaged.passUnretained(event)
	}

	let this = Unmanaged<MediaKeyHandler>.fromOpaque(obj).takeUnretainedValue()
	if !this.enabled {
		return Unmanaged.passUnretained(event)
	}

	if [.tapDisabledByTimeout, .tapDisabledByUserInput ].contains(type)
		|| type != CGEventType(rawValue: UInt32(NX_SYSDEFINED))
	{
		if type == .tapDisabledByTimeout {
			CGEvent.tapEnable(tap: this.eventTap, enable: true)
		}

		return Unmanaged.passUnretained(event)
	}

	// NSScreenChangedEventType == 8
	guard let nse = NSEvent(cgEvent: event), nse.subtype == .screenChanged else {
		return Unmanaged.passUnretained(event)
	}

	let keycode = Int32((nse.data1 & 0xFFFF0000) >> 16)

	if ![NX_KEYTYPE_PLAY, NX_KEYTYPE_FAST, NX_KEYTYPE_NEXT, NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND].contains(keycode) {
		return Unmanaged.passUnretained(event)
	}

	let flags = (nse.data1 & 0x0000FFFF)
	let isPressed = (((flags & 0xFF00) >> 8)) == 0xA

	if isPressed
	{
		guard let vm = this.controller?.getViewModel() as? MainModel else {
			return nil
		}

		if keycode == NX_KEYTYPE_PLAY
		{
			print("media key: play/pause")

			// poke it, so the play/pause button updates properly.
			vm.isPlaying.toggle()
			vm.poke()
		}
		else if keycode == NX_KEYTYPE_NEXT || keycode == NX_KEYTYPE_FAST
		{
			print("media key: next")
			this.controller?.nextSong()
		}
		else if keycode == NX_KEYTYPE_PREVIOUS || keycode == NX_KEYTYPE_REWIND
		{
			print("media key: prev")
			this.controller?.previousSong()
		}

//		globalMediaKeyHandler.updateMediaCentre(with: nil, state: vm.getPlaybackState())
	}

	return nil
}

