// SettingsView.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import IOKit.pwr_mgt
import Foundation

class InsomniaInducer
{
	private static let kIOPMAssertPreventUserIdleDisplaySleep = "PreventUserIdleDisplaySleep" as CFString

	private var assertion: IOPMAssertionID? = nil
	private var enabled: Bool = false

	init()
	{
	}

	deinit
	{
		self.deactivate()
	}

	func enable()
	{
		self.enabled = true
	}

	func disable()
	{
		self.enabled = false
		if self.assertion != nil {
			self.deactivate()
		}
	}

	func isActivated() -> Bool
	{
		return self.assertion != nil
	}

	func activate()
	{
		guard self.enabled && self.assertion == nil else {
			return
		}

		var assertion = IOPMAssertionID(0)
		let succ = IOPMAssertionCreateWithName(InsomniaInducer.kIOPMAssertPreventUserIdleDisplaySleep,
											   IOPMAssertionLevel(kIOPMAssertionLevelOn),
											   "moestreamer" as CFString,
											   &assertion)

		guard succ == kIOReturnSuccess else {
			Logger.error("iokit", msg: "failed to prevent sleep: \(succ)")
			return
		}

		self.assertion = assertion
		Logger.log("iokit", msg: "idle sleep blocked")
	}

	func deactivate()
	{
		// note: don't guard on self.enabled, since when you disable it we should unsleep too.
		guard let assertion = self.assertion else {
			return
		}

		let succ = IOPMAssertionRelease(assertion)
		guard succ == kIOReturnSuccess else {
			Logger.error("iokit", msg: "failed to enable sleep (?!): \(succ)")
			return
		}

		Logger.log("iokit", msg: "idle sleep enabled")
		self.assertion = nil
	}
}
