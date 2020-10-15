// AppDelegate.swift
// Copyright (c) 2019, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate : NSObject, NSApplicationDelegate
{
	var controller: ViewController!

	func applicationDidFinishLaunching(_ aNotification: Notification)
	{
		self.controller = ViewController()

		// register the media key handler, if need to.
		globalMediaKeyHandler.enable(Settings.get(.shouldUseMediaKeys()),
									 musicCon: self.controller.getModel().controller())

		// register the sleep handler, so we pause on sleep. no need to resume on wakeup,
		// cos that'll be annoying.
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(AppDelegate.onSleep),
														  name: NSWorkspace.willSleepNotification, object: nil)

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
		self.controller.getModel().isPlaying = false
		self.controller.getModel().poke()
	}

	func applicationWillTerminate(_ aNotification: Notification)
	{
		// Insert code here to tear down your application
		globalMediaKeyHandler.enable(false, musicCon: self.controller.getModel().controller())
	}
}
