// AppDelegate.swift
// Copyright (c) 2019, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{
	var menuItem: MenuItemController!

	func applicationDidFinishLaunching(_ aNotification: Notification)
	{
		self.menuItem = MenuItemController()
	}

	func applicationWillTerminate(_ aNotification: Notification)
	{
		// Insert code here to tear down your application
	}
}

