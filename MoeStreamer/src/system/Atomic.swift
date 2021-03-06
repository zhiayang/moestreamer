// Atomic.swift
// Copyright (c) 2021, zhiayang
// Licensed under the Apache License Version 2.0.

import Foundation

struct Atomic64
{
	private(set) var value: Int64

	init(_ initial: Int64)
	{
		self.value = initial
	}

	// the OSAtomic functions return the new value; to get the old value we just do an
	// offset, which is perfectly safe since we know for sure the incr/decr already happened.
	mutating func incr() -> Int64 { return OSAtomicIncrement64(&self.value) - 1 }
	mutating func decr() -> Int64 { return OSAtomicDecrement64(&self.value) + 1 }
}
