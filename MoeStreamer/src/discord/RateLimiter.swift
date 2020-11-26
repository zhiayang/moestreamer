// RateLimiter.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Foundation

class RateLimiter
{
	// 5 updates per 20 seconds.
	private let period: TimeInterval
	private let refill: Int

	private var callback: (Song, PlaybackState) -> Void
	private var remaining: Int
	private var lastRefill: Date
	private var queuedUpdate: (Song, PlaybackState)? = nil
	private var dispatch: DispatchQueue

	init(_ refill: Int, every interval: TimeInterval, callback: @escaping (Song, PlaybackState) -> Void, dispatch: DispatchQueue)
	{
		self.refill = refill
		self.period = interval
		self.remaining = refill
		self.callback = callback

		self.lastRefill = Date()
		self.queuedUpdate = nil
		self.dispatch = dispatch
	}

	func enqueueUpdate(for song: Song, state: PlaybackState)
	{
		if self.now().timeIntervalSince(self.lastRefill) > self.period {
			self.remaining = self.refill
		}

		if self.remaining > 0 {
			self.remaining -= 1
			self.dispatch.async {
				self.callback(song, state)
			}
			return
		}

		// we need to wait.
		// if there's stuff being queued, just discard it.
		self.queuedUpdate = (song, state)

		// setup a job
		self.dispatch.asyncAfter(deadline: .now() + self.timeUntilRefill()) {
			// only send if nobody else overrode us.
			if self.queuedUpdate?.0 == song && self.queuedUpdate?.1 == state {
				self.enqueueUpdate(for: song, state: state)
			}
		}
	}

	private func now() -> Date
	{
		return Date()
	}

	private func timeUntilRefill() -> TimeInterval
	{
		let elapsed = self.now().timeIntervalSince(self.lastRefill)
		return self.period - elapsed
	}
}
