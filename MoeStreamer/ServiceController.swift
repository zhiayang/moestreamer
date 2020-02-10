// ServiceController.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import Foundation

struct Song
{
	var title: String = ""
	var album: (String?, NSImage?) = (nil, nil)
	var artists: [String] = [ ]

	enum FavouriteState
	{
		case Yes
		case No
		case PendingYes
		case PendingNo

		func icon() -> NSImage
		{
			switch self
			{
				case .Yes:     return #imageLiteral(resourceName: "Favourited")
				case .No:      return #imageLiteral(resourceName: "FavouritedHollow")

				case .PendingYes, .PendingNo:
					return #imageLiteral(resourceName: "FavouritedHalf")
			}
		}

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

	var isFavourite: FavouriteState = .No
	let id: Int
}

protocol ServiceController
{
	func getStreamURL() -> URL
	func getCurrentSong() -> Song?
	func refresh()
	func start()
	func pause()
	func stop()

	func toggleFavourite()
	func sessionLogin(activityView: ViewWrapper)

	func audioController() -> AudioController

	init(activityView: ViewWrapper)
}
