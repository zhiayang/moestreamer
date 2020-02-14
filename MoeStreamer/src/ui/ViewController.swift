// ViewController.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.


import Cocoa
import SwiftUI
import Combine
import Foundation


class ViewController : NSObject, NSPopoverDelegate
{
	private var statusBar: NSStatusBar
	private var statusItem: NSStatusItem
	private var statusBarButton: NSStatusBarButton

	private var popover: CustomPopover

	private var viewModel: MainModel! = nil
	private var rootView: MainView! = nil


	override init()
	{
		self.popover = CustomPopover()
		self.statusBar = NSStatusBar()
		self.statusItem = statusBar.statusItem(withLength: 28.0)
		self.statusBarButton = statusItem.button!

		super.init()

		self.viewModel = MainModel(controller: ListenMoeController())
		self.viewModel.musicCon.setViewModel(viewModel: self.viewModel)
		
		self.rootView = MainView(model: self.viewModel)
		
		statusBarButton.image = NSImage(named: "Icon")
		statusBarButton.image?.size = NSSize(width: 16.0, height: 16.0)
		statusBarButton.image?.isTemplate = true
		statusBarButton.action = #selector(togglePopover(sender:))
		statusBarButton.target = self


		popover.contentSize = NSSize(width: 240, height: 240)
		popover.contentViewController = NSHostingController(rootView: self.rootView)
		popover.behavior = .transient
		popover.delegate = self

		popover.keydownHandler = { (event) in
			if Settings.get(.shouldUseKeyboardShortcuts())
			{
				switch event.characters?.first?.asciiValue
				{
					case UInt8(ascii: "m"):
						self.viewModel.isMuted.toggle()

					case UInt8(ascii: " "):
						self.viewModel.isPlaying.toggle()

					case UInt8(ascii: "\u{1b}"):
						self.popover.performClose(nil)

					default:
						break
				}
			}
		}
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

class CustomPopover : NSPopover
{
	var keydownHandler: ((NSEvent) -> Void)? = nil

	override func keyDown(with event: NSEvent)
	{
		self.keydownHandler?(event)
	}
}

class MainModel : ViewModel, ObservableObject
{
	@Published fileprivate var musicCon: ServiceController
	@Published private var dummy: Bool = false

	@Published var status: String = ""
	@Published var spinning: Int = 0

	@Published var songTitle: String = ""
	@Published var songArtist: String = ""
	@Published var albumArt: AnyView?

	// state for view-specific shenanigans
	@Published var textOpacity: Double = 1.0
	@Published var favOpacity: Double = 0.0
	@Published var truncateArtists: Bool = false

	private var currentSong: Song? = nil

//	let objectWillChange = PassthroughSubject<Void, Never>()
	var isPlaying: Bool = false {
		didSet {
			if isPlaying
			{
				self.musicCon.start()
				self.musicCon.audioController().play()
			}
			else
			{
				self.musicCon.audioController().pause()
				self.musicCon.pause()
			}
		}
	}

	var isMuted: Bool {
		get { self.musicCon.audioController().isMuted() }
		set {
			if newValue
			{
				self.musicCon.audioController().mute()
			}
			else
			{
				self.musicCon.audioController().unmute()
			}
		}
	}

	var volume: Int {
		get { self.musicCon.audioController().getVolume() }
		set {
			self.musicCon.audioController().setVolume(volume: newValue)
		}
	}


	func spin()
	{
		DispatchQueue.main.async {
			withAnimation(.easeIn(duration: 0.35)) {
				self.spinning += 1
			}
		}
	}

	func unspin()
	{
		DispatchQueue.main.async {
			withAnimation(.easeOut(duration: 0.35)) {
				if self.spinning > 0 {
					self.spinning -= 1
				}
			}
		}
	}

	func setStatus(s: String, timeout: TimeInterval? = nil)
	{
		DispatchQueue.main.async {
			withAnimation(.easeIn(duration: 0.25)) {
				self.status = s
			}
		}

		if let t = timeout {
			// can't update the UI in background threads.
			DispatchQueue.main.asyncAfter(deadline: .now() + t) {
				withAnimation(.easeOut(duration: 0.45)) {
					self.status = ""
				}
			}
		}
	}

	private static func getDefaultAlbumArt() -> AnyView
	{
		return AnyView(Image(nsImage: #imageLiteral(resourceName: "NoCoverArt2"))
			.resizable()
			.saturation(0.85)
			.background(Rectangle()
				.foregroundColor(Color(.sRGB, red: 0.114, green: 0.122, blue: 0.169))
			)
		)
	}

	func onSongChange(song: Song?)
	{
		// welcome to the land of toxicity.
		let animDuration = 0.25

		// the album art can be animated normally:
		DispatchQueue.main.async {
			withAnimation(.easeInOut(duration: animDuration)) {

				switch song?.isFavourite
				{
					case .Yes:
						self.favOpacity = 1.0

					case .PendingYes:
						self.favOpacity = 0.25

					case .PendingNo:
						self.favOpacity = 0.50

					default:
						self.favOpacity = 0.0
				}
				
				if let art = song?.album.1
				{
					self.albumArt = AnyView(Image(nsImage: art).resizable())
				}
				else
				{
					self.albumArt = Self.getDefaultAlbumArt()
				}
			}

			// the text must be animated manually, using opacity. only do this if the song is not the same.
			// since we are adjusting the opacity manually, SwiftUI cannot "optimise away" the animation if
			// the new value is the same as the old value.
			if let s = self.currentSong, s == song {
				return
			}

			self.currentSong = song
			withAnimation(.easeOut(duration: animDuration)) {
				self.textOpacity = 0

				DispatchQueue.main.asyncAfter(deadline: .now() + animDuration) {

					if let song = song
					{
						self.songTitle = song.title
						self.songArtist = song.artists.joined(separator: ", ")
					}
					else
					{
						self.songTitle = "not playing"
						self.songArtist = "—"
					}

					withAnimation(.easeIn(duration: animDuration)) {
						self.textOpacity = 1
					}
				}
			}
		}
	}

	func poke()
	{
		DispatchQueue.main.async {
			self.dummy.toggle()
		}
	}

	func controller() -> ServiceController
	{
		return self.musicCon
	}

	init(controller: ServiceController)
	{
		self.musicCon = controller
		self.onSongChange(song: nil)
	}
}