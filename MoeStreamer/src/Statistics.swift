// Statistics.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import SwiftUI
import Foundation

class Statistics : ObservableObject
{
	@Published private(set) var songsPlayed: Int

	static var instance = Statistics()
	
	init()
	{
		self.songsPlayed = Settings.get(.statSongsPlayed())
	}

	private func sync()
	{
		Settings.set(.statSongsPlayed(), value: self.songsPlayed)
	}

	func logSongPlayed()
	{
		DispatchQueue.main.async {
			self.songsPlayed += 1
		}
		
		self.sync()
	}

	func reset()
	{
		self.songsPlayed = 0
		self.sync()
	}
}
