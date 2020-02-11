// MenuItemController.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.


import Cocoa
import SwiftUI
import Foundation

class CustomPopover : NSPopover
{
	override func keyDown(with event: NSEvent) {
		print("key down")
	}
}

class MenuItemController : NSObject, NSPopoverDelegate
{
	private var statusBar: NSStatusBar
	private var statusItem: NSStatusItem
	private var statusBarButton: NSStatusBarButton

	private var popover: CustomPopover


	private var viewWrapper = ViewWrapper()
	private var musicCon: ServiceController! = nil
	private var rootView: MainView! = nil


	override init()
	{
		self.popover = CustomPopover()
		self.statusBar = NSStatusBar()
		self.statusItem = statusBar.statusItem(withLength: 28.0)
		self.statusBarButton = statusItem.button!

		super.init()

		self.musicCon = ListenMoeController(activityView: self.viewWrapper)
		self.rootView = MainView(controller: self.musicCon, viewWrapper: self.viewWrapper)
		
		statusBarButton.image = NSImage(named: "Icon")
		statusBarButton.image?.size = NSSize(width: 16.0, height: 16.0)
		statusBarButton.image?.isTemplate = true
		statusBarButton.action = #selector(togglePopover(sender:))
		statusBarButton.target = self


		popover.contentSize = NSSize(width: 240, height: 240)
		popover.contentViewController = NSHostingController(rootView: self.rootView)
		popover.behavior = .transient
		popover.delegate = self
	}

	@objc func togglePopover(sender: AnyObject)
	{
		if(popover.isShown)
		{
			popover.performClose(sender)
		}
		else
		{
			popover.show(relativeTo: statusBarButton.bounds, of: statusBarButton,
						 preferredEdge: NSRectEdge.maxY)
			popover.contentViewController?.view.window?.makeKey()
		}
	}

	func popoverDidClose(_ notification: Notification)
	{
		self.rootView.showingSettings = false

		// dirty, but reset the controller with a fresh copy so we start from the
		// root view.
		popover.contentViewController = NSHostingController(rootView: self.rootView)
	}
}
