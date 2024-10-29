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
	static var shared: AppDelegate! = nil

	override init()
	{
		super.init()
		AppDelegate.shared = self
	}

	func applicationDidFinishLaunching(_ aNotification: Notification)
	{
		self.controller = ViewController()

		// register the media key handler, if need to.
		globalMediaKeyHandler.enable(Settings.get(.shouldUseMediaKeys()),
									 musicCon: self.controller.getModel().controller())

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
			self.controller.showPopover()
		}
	}

	func applicationWillTerminate(_ aNotification: Notification)
	{
		globalMediaKeyHandler.enable(false, musicCon: self.controller.getModel().controller())
		self.controller.shutdown()
	}
}
