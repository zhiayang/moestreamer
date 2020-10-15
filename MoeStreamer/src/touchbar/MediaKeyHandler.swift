// MediaKeyHandler.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import Foundation

class MediaKeyHandler
{
	fileprivate var enabled: Bool = false
	fileprivate var eventTap: CFMachPort! = nil
	fileprivate var runLoopSource: CFRunLoopSource! = nil
	fileprivate var controller: ServiceController! = nil

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
			CGEvent.tapEnable(tap: self.eventTap, enable: false)
			CFRunLoopRemoveSource(CFRunLoopGetMain(), self.runLoopSource, .commonModes)
			CFMachPortInvalidate(self.eventTap)

			Logger.log(msg: "media keys ignored")
			self.enabled = false
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

var globalMediaKeyHandler = MediaKeyHandler()

fileprivate func handlerCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
								 refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>?
{
	guard let obj = refcon else {
		return Unmanaged.passRetained(event)
	}

	let this = Unmanaged<MediaKeyHandler>.fromOpaque(obj).takeUnretainedValue()
	if !this.enabled {
		return Unmanaged.passRetained(event)
	}

	if [.tapDisabledByTimeout, .tapDisabledByUserInput ].contains(type)
		|| type != CGEventType(rawValue: UInt32(NX_SYSDEFINED))
	{
		if type == .tapDisabledByTimeout {
			CGEvent.tapEnable(tap: this.eventTap, enable: true)
		}

		return Unmanaged.passRetained(event)
	}

	// NSScreenChangedEventType == 8
	guard let nse = NSEvent(cgEvent: event), nse.subtype == .screenChanged else {
		return Unmanaged.passRetained(event)
	}

	let keycode = Int32((nse.data1 & 0xFFFF0000) >> 16)

	if ![NX_KEYTYPE_PLAY, NX_KEYTYPE_FAST, NX_KEYTYPE_NEXT].contains(keycode) {
		return Unmanaged.passRetained(event)
	}

	let flags = (nse.data1 & 0x0000FFFF)
	let isPressed = (((flags & 0xFF00) >> 8)) == 0xA

	if isPressed
	{
		if keycode == NX_KEYTYPE_PLAY
		{
			print("media key: play/pause")

			// poke it, so the play/pause button updates properly.
			(this.controller.getViewModel() as? MainModel)?.isPlaying.toggle()
			this.controller.getViewModel()?.poke()
		}
		else if keycode == NX_KEYTYPE_NEXT || keycode == NX_KEYTYPE_FAST
		{
			this.controller.nextSong()
			print("media key: next")
		}
	}

	return nil
}

