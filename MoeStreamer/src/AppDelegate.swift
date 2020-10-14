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

		globalMediaKeyHandler.enable(Settings.get(.shouldUseMediaKeys()),
									 musicCon: self.controller.getModel().controller())

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			self.controller.showPopover()
		}

		if Settings.get(.shouldNotifySongChange()) {
			Notifier.create()
		}
	}

	func applicationWillTerminate(_ aNotification: Notification)
	{
		// Insert code here to tear down your application
		globalMediaKeyHandler.enable(false, musicCon: self.controller.getModel().controller())
	}
}
