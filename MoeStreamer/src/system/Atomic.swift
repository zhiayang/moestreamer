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


class Synchronised<T>
{
	private var m_value: T
	private var m_queue: DispatchQueue!

	init(value: T)
	{
		self.m_value = value

		let address = Unmanaged.passUnretained(self).toOpaque()
		self.m_queue = DispatchQueue(label: "accessQueue.\(type(of: self)).\(address)")
	}

	func write(_ closure: (T) -> T)
	{
		self.m_queue.sync { [weak self] in
			guard let self = self else { return }
			self.m_value = closure(self.m_value)
		}
	}

	func read(_ closure: (T) -> Void)
	{
		self.m_queue.sync { [weak self] in
			guard let self = self else { return }
			closure(self.m_value)
		}
	}

	func value() -> T
	{
		var ret: T!
		self.read({ ret = $0 })
		return ret
	}

	func set(value: T)
	{
		self.write({ _ in
			return value
		})
	}
}
