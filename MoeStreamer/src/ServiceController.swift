// ServiceController.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import Foundation
import UserNotifications

struct Song : Equatable, Identifiable
{
	let id: Int
	var title: String = ""
	var album: (String?, NSImage?) = (nil, nil)
	var artists: [String] = [ ]
	var isFavourite: FavouriteState = .No

	enum FavouriteState
	{
		case Yes
		case No
		case PendingYes
		case PendingNo

		mutating func toggle()
		{
			switch self
			{
				case .Yes, .PendingYes:
					self = .PendingNo

				case .No, .PendingNo:
					self = .PendingYes
			}
		}

		mutating func finalise()
		{
			switch self
			{
				case .Yes, .PendingYes:
					self = .Yes

				case .No, .PendingNo:
					self = .No
			}
		}

		mutating func cancel()
		{
			switch self
			{
				case .PendingYes:
					self = .No

				case .PendingNo:
					self = .Yes

				default:
					break
			}
		}

		var bool: Bool { get { self == .Yes || self == .PendingYes } }
	}

	static func == (lhs: Song, rhs: Song) -> Bool
	{
		return lhs.id == rhs.id
	}
}

struct ServiceCapabilities : OptionSet
{
	let rawValue: Int

	static let favourite       = ServiceCapabilities(rawValue: 1 << 0)
	static let serverSidePause = ServiceCapabilities(rawValue: 1 << 1)
	static let previousTrack   = ServiceCapabilities(rawValue: 1 << 2)
	static let nextTrack       = ServiceCapabilities(rawValue: 1 << 3)
	static let searchTracks    = ServiceCapabilities(rawValue: 1 << 4)
}

protocol ServiceController : AnyObject
{
	func getCurrentSong() -> Song?
	func refresh()
	func start()
	func pause()
	func stop()

	func isReady() -> Bool

	func nextSong()

	func toggleFavourite()

	func audioController() -> AudioController
	func getCapabilities() -> ServiceCapabilities

	func searchSongs(name: String) -> [Song];

	func setNextSong(_ song: Song, immediately: Bool)

	init(viewModel: ViewModel?)

	func setViewModel(viewModel: ViewModel)
	func getViewModel()-> ViewModel?
}


class Notifier
{
	private let nc = UNUserNotificationCenter.current()

	public static var instance: Notifier? = nil

	static func create()
	{
		if Notifier.instance == nil {
			Notifier.instance = Notifier()
		}
	}

	init()
	{
		print("make notifier")
		self.nc.requestAuthorization(options: [ .alert ]) { (granted, error) in
		}
	}

	func notify(song: Song)
	{
		if !Settings.get(.shouldNotifySongChange()) {
			return
		}

		let content = UNMutableNotificationContent()
		content.title = song.title
		content.body = song.artists.joined(separator: ", ")

		print("notifying \(song.title)")

		let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
		let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

		self.nc.add(request)
	}
}
