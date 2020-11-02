// ServiceController.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import SwiftUI
import Foundation
import UserNotifications

struct Song : Equatable, Identifiable, Hashable
{
	let id: Int
	var title: String = ""
	var album: (String?, NSImage?) = (nil, nil)
	var artists: [String] = [ ]
	var isFavourite: FavouriteState = .No
	var duration: Double? = nil

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

	func hash(into hasher: inout Hasher)
	{
		hasher.combine(self.id)
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
	static let timeInfo        = ServiceCapabilities(rawValue: 1 << 5)
}

protocol ServiceController : AnyObject
{
	init(viewModel: ViewModel?)

	func getCurrentSong() -> Song?
	func refresh()
	func start()
	func pause()
	func stop()

	func isReady() -> Bool

	func nextSong()
	func previousSong()

	func toggleFavourite()

	func audioController() -> AudioController
	func getCapabilities() -> ServiceCapabilities

	func searchSongs(name: String, into: Binding<[Song]>, inProgress: ((Song) -> Void)?, onComplete: @escaping () -> Void)
	func enqueueSong(_ song: Song, immediately: Bool)

	func setViewModel(viewModel: ViewModel)
	func getViewModel() -> ViewModel?
}

extension ServiceController
{
	func nextSong()
	{
	}

	func previousSong()
	{
	}

	func searchSongs(name: String, into: Binding<[Song]>, inProgress: ((Song) -> Void)? = nil, onComplete: @escaping () -> Void)
	{
	}

	func enqueueSong(_ song: Song, immediately: Bool)
	{
	}
}
