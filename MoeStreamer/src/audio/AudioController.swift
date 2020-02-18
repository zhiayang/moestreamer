// AudioController.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Foundation

protocol AudioController
{
	func setVolume(volume: Int)
	func getVolume() -> Int

	func mute()
	func unmute()
	func isMuted() -> Bool

	func play()
	func pause()
	func stop()
	func isPlaying() -> Bool
}
