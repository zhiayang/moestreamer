// MediaKeyHandler.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import Foundation
import MediaPlayer

@available(macOS 10.12.2, *)
fileprivate extension NSTouchBarItem.Identifier
{
	static let playPause = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).TouchBarItem.playPause")
}

class MediaKeyHandler : NSObject
{
	fileprivate var enabled: Bool = false
	fileprivate var eventTap: CFMachPort! = nil
	fileprivate var controller: ServiceController? = nil
	fileprivate var runLoopSource: CFRunLoopSource! = nil

	override init()
	{
		super.init()
		self.updateMediaCentre(with: nil)
	}

	@objc func handleEvent(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus
	{
		guard let vm = self.controller?.getViewModel() as? MainModel else {
			return .success
		}

		let remote = MPRemoteCommandCenter.shared()

		switch event.command {
			case remote.playCommand:
				vm.isPlaying = true

			case remote.pauseCommand:
				vm.isPlaying = false

			case remote.togglePlayPauseCommand:
				vm.isPlaying.toggle()

			case remote.nextTrackCommand:
				vm.controller().nextSong()

			case remote.previousTrackCommand:
				vm.controller().previousSong()

			default:
				break
		}
		vm.poke()
		return .success
	}

	private func activateMPRemote()
	{
		let remote = MPRemoteCommandCenter.shared()
		remote.playCommand.isEnabled = true
		remote.playCommand.addTarget(self, action: #selector(handleEvent))

		remote.pauseCommand.isEnabled = true
		remote.pauseCommand.addTarget(self, action: #selector(handleEvent))

		remote.togglePlayPauseCommand.isEnabled = true
		remote.togglePlayPauseCommand.addTarget(self, action: #selector(handleEvent))

		remote.previousTrackCommand.isEnabled = true
		remote.previousTrackCommand.addTarget(self, action: #selector(handleEvent))

		remote.nextTrackCommand.isEnabled = true
		remote.nextTrackCommand.addTarget(self, action: #selector(handleEvent))
		MPNowPlayingInfoCenter.default().playbackState = .paused
	}


	private func deactivateMPRemote()
	{
		let remote = MPRemoteCommandCenter.shared()

		remote.playCommand.removeTarget(self)
		remote.pauseCommand.removeTarget(self)
		remote.nextTrackCommand.removeTarget(self)
		remote.previousTrackCommand.removeTarget(self)
		remote.togglePlayPauseCommand.removeTarget(self)

		MPNowPlayingInfoCenter.default().playbackState = .stopped
	}

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
		self.activateMPRemote()
	}

	private func destroy()
	{
		if self.enabled
		{
			self.enabled = false

			CGEvent.tapEnable(tap: self.eventTap, enable: false)
			CFRunLoopRemoveSource(CFRunLoopGetMain(), self.runLoopSource, .commonModes)
			CFMachPortInvalidate(self.eventTap)

			Logger.log(msg: "media keys ignored")
			self.deactivateMPRemote()
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

	private func getMetadata(for song: Song?) -> [String: Any]
	{
		var ret = [String: Any]()
		guard let song = song else {
			return ret
		}

		ret[MPMediaItemPropertyTitle] = song.title
		ret[MPMediaItemPropertyArtist] = song.artists.joined(separator: ", ")
		ret[MPMediaItemPropertyPlaybackDuration] = song.duration
		ret[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0

		guard let art = song.album.1 else {
			ret[MPMediaItemPropertyArtwork] = nil
			return ret
		}

		let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: art.size.width, height: art.size.height),
										 requestHandler: { _ in return art })

		ret[MPMediaItemPropertyArtwork] = artwork

		return ret
	}

	func updateMediaCentre(with song: Song?)
	{
		let vm = self.controller?.getViewModel() as? MainModel

		MPNowPlayingInfoCenter.default().nowPlayingInfo = self.getMetadata(for: song ?? vm?.getCurrentSong())
		MPNowPlayingInfoCenter.default().playbackState = (vm?.isPlaying ?? false)
			? .playing
			: .paused

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

	if ![NX_KEYTYPE_PLAY, NX_KEYTYPE_FAST, NX_KEYTYPE_NEXT, NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND].contains(keycode) {
		return Unmanaged.passRetained(event)
	}

	let flags = (nse.data1 & 0x0000FFFF)
	let isPressed = (((flags & 0xFF00) >> 8)) == 0xA

	if isPressed
	{
		if keycode == NX_KEYTYPE_PLAY
		{
			print("media key: play/pause")

			let vm = this.controller?.getViewModel() as? MainModel

			// poke it, so the play/pause button updates properly.
			vm?.isPlaying.toggle()
			vm?.poke()
		}
		else if keycode == NX_KEYTYPE_NEXT || keycode == NX_KEYTYPE_FAST
		{
			print("media key: next")
			this.controller?.nextSong()
		}
		else if keycode == NX_KEYTYPE_PREVIOUS || keycode == NX_KEYTYPE_REWIND
		{
			print("media key: prev")
			this.controller?.previousSong()
		}

		globalMediaKeyHandler.updateMediaCentre(with: nil)
	}

	return nil
}

