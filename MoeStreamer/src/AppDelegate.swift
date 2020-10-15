// AppDelegate.swift
// Copyright (c) 2019, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate : NSObject, NSApplicationDelegate
{
	var controller: ViewController!
	var wasPlayingWhenSlept: Bool = false

	func applicationDidFinishLaunching(_ aNotification: Notification)
	{
		self.controller = ViewController()

		// register the media key handler, if need to.
		globalMediaKeyHandler.enable(Settings.get(.shouldUseMediaKeys()),
									 musicCon: self.controller.getModel().controller())

		// register the sleep handler, so we pause on sleep.
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(AppDelegate.onSleep),
														  name: NSWorkspace.willSleepNotification, object: nil)

		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(AppDelegate.onWake),
														  name: NSWorkspace.didWakeNotification, object: nil)

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			self.controller.showPopover()
		}

		if Settings.get(.shouldNotifySongChange()) {
			Notifier.create()
		}
	}

	@objc func onSleep()
	{
		Logger.log(msg: "pausing playback due to sleep")
		self.wasPlayingWhenSlept = self.controller.getModel().isPlaying

		self.controller.getModel().isPlaying = false
		self.controller.getModel().poke()
	}

	@objc func onWake()
	{
		if self.wasPlayingWhenSlept && Settings.get(.shouldResumeOnWake())
		{
			self.wasPlayingWhenSlept = false
			Logger.log(msg: "resuming playback")

			self.controller.getModel().isPlaying = true
			self.controller.getModel().poke()
		}
	}

	func applicationWillTerminate(_ aNotification: Notification)
	{
		// Insert code here to tear down your application
		globalMediaKeyHandler.enable(false, musicCon: self.controller.getModel().controller())
	}
}
