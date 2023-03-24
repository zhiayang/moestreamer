// ViewController.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.


import Cocoa
import SwiftUI
import Combine
import Foundation

enum PlaybackState : Equatable
{
	case Playing(elapsed: Double)
	case Paused(elapsed: Double)

	var elapsed: Double {
		switch self
		{
			case .Playing(let elapsed): return elapsed
			case .Paused(let elapsed):  return elapsed
		}
	}

	var playing: Bool { if case .Playing(_) = self { return true } else { return false } }
}

class ViewController : NSObject, NSPopoverDelegate
{
	private var statusBar: NSStatusBar
	private var statusItem: NSStatusItem
	private var statusBarButton: NSStatusBarButton

	private var popover: CustomPopover

	private var viewModel: MainModel! = nil
	private var rootView: MainView! = nil
	private var ikuraRPC: IkuraRPC? = nil
	private var discordRPC: DiscordRPC? = nil

	private var nowPlayingCentre: NowPlayingCentre! = nil
	private var insomniaInducer = InsomniaInducer()

	override init()
	{
		self.popover = CustomPopover()
		self.statusBar = NSStatusBar()
		self.statusItem = statusBar.statusItem(withLength: 28.0)
		self.statusBarButton = statusItem.button!

		super.init()

		switch(Settings.getKE(.musicBackend()) as MusicBackend)
		{
			case .ListenMoe:
				self.viewModel = MainModel(backend: ListenMoeController.self)

			case .LocalMusic:
				self.viewModel = MainModel(backend: LocalMusicController.self)
		}

		self.rootView = MainView(model: self.viewModel)
		self.nowPlayingCentre = NowPlayingCentre(controller: self.viewModel.controller())

		// make the viewmodel update the NowPlaying info
		self.viewModel.subscribe(with: { song, state in
			self.nowPlayingCentre.updateMediaCentre(with: song, state: state)
		})

		let _ = Settings.observe(.shouldUseDiscordPresence(), callback: { key in
			let v: Bool = Settings.get(key)
			if v && self.discordRPC == nil {
				self.discordRPC = DiscordRPC(model: self.viewModel)
				let _ = self.discordRPC?.connect()
			} else if !v {
				self.discordRPC?.disconnect()
				self.discordRPC = nil
			}
		})

		let _ = Settings.observe(.ikuraEnabled(), callback: { key in
			let v: Bool = Settings.get(key)
			if v && self.ikuraRPC == nil {
				self.ikuraRPC = IkuraRPC(model: self.viewModel)
				let _ = self.ikuraRPC?.connect()
			} else if !v {
				self.ikuraRPC?.disconnect()
				self.ikuraRPC = nil
			}
		})

		let _ = Settings.observe(.shouldPreventIdleSleep(), callback: { key in
			Settings.get(key)
				? self.insomniaInducer.enable()
				: self.insomniaInducer.disable()

			// InsomniaInducer::activate() will check that its activated, so no need to check here.
			// if the setting changed while a song was playing, then also disable sleep so we don't
			// need to wait till the song changes.
			if self.viewModel.isPlaying {
				self.insomniaInducer.activate()
			}
		})

		self.viewModel.subscribe(with: { song, state in
			if state.playing {
				self.insomniaInducer.activate()
			} else {
				self.insomniaInducer.deactivate()
			}
		})

		// notify the observers (ie. conditionally connect to discord RPC -- that's the sole purpose)
		// in a separate queue, so we don't block the rest of the initialisation of the app while
		// the rpc client does the ipc open + album art upload + other nonsense.
		DispatchQueue.main.async {
			Settings.notifyObservers(for: .shouldUseDiscordPresence())
			Settings.notifyObservers(for: .ikuraEnabled())
		}

		statusBarButton.image = NSImage(named: "Icon")
		statusBarButton.image?.size = NSSize(width: 16.0, height: 16.0)
		statusBarButton.image?.isTemplate = true
		statusBarButton.action = #selector(togglePopover(sender:))
		statusBarButton.target = self

		popover.contentViewController = NSHostingController(rootView: self.rootView)
		popover.behavior = .transient
		popover.delegate = self

		let setupShortcuts = { [self] in
			popover.keydownHandler = { (event) in
				switch event.characters?.first?.asciiValue
				{
					case UInt8(ascii: "m"):
						self.viewModel.isMuted.toggle()
						self.viewModel.poke()

					case UInt8(ascii: " "): fallthrough
					case UInt8(ascii: "k"):
						self.viewModel.isPlaying.toggle()
						self.viewModel.poke()

					case UInt8(ascii: "j"):
						self.viewModel.controller().previousSong()

					case UInt8(ascii: "l"):
						self.viewModel.controller().nextSong()

					case UInt8(ascii: "f"):
						self.viewModel.controller().toggleFavourite()

					case UInt8(ascii: "\u{1b}"):
						if self.rootView.currentSubView == .None
						{
							self.popover.performClose(nil)
						}
						else
						{
							self.rootView.currentSubView.toggle(into: .None)
						}

					case UInt8(ascii: "/"):
						if self.viewModel.controller().getCapabilities().contains(.searchTracks)
						{
							self.rootView.currentSubView.toggle(into: .Search)
							self.viewModel.poke()
						}

					default:
						break
				}
			}
		}

		// for some obscure reason, this method works on 10.15, not 11, and not 13.
		if #unavailable(macOS 11.0)
		{
			setupShortcuts()
		}
		else if #available(macOS 13.0, *)
		{
			setupShortcuts()
		}
	}

	func shutdown()
	{
		if self.discordRPC != nil {
			self.discordRPC?.disconnect()
		}

		if self.ikuraRPC != nil {
			self.ikuraRPC?.disconnect()
		}
	}

	func getModel() -> MainModel
	{
		return self.viewModel
	}

	func showPopover()
	{
		self.popover.contentSize = NSSize(width: MainView.VIEW_WIDTH, height: MainView.VIEW_HEIGHT)
		self.popover.show(relativeTo: statusBarButton.bounds, of: statusBarButton,
						  preferredEdge: NSRectEdge.minY)
		self.popover.contentViewController?.view.window?.makeKey()
	}

	func closePopover(sender: AnyObject?)
	{
		self.popover.performClose(sender)
	}

	@objc func togglePopover(sender: AnyObject)
	{
		if(popover.isShown) {
			self.closePopover(sender: sender)
		} else {
			self.showPopover()
		}
	}

	func becomeFirstResponder()
	{
		self.popover.contentViewController?.view.window?.makeFirstResponder(self.popover)
	}

	func popoverDidClose(_ notification: Notification)
	{
		self.rootView.currentSubView.kind = .None

		// dirty, but reset the controller with a fresh copy so we start from the
		// root view.
		popover.contentViewController = NSHostingController(rootView: self.rootView)
	}
}

class CustomPopover : NSPopover
{
	var keydownHandler: ((NSEvent) -> Void)? = nil

	override func keyDown(with event: NSEvent)
	{
		self.keydownHandler?(event)
	}
}
