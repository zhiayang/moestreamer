// MusicBackend.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Foundation

protocol KeyedEnum
{
	var keyedValue: String { get }
	init?(with: String)
}

enum MusicBackend : Hashable, KeyedEnum, CustomStringConvertible
{
	static let values: [Self] = [ .ListenMoe(), .LocalMusic() ]

	case ListenMoe(name: String = "LISTEN.moe", key: String = "listenMoe")
	case LocalMusic(name: String = "iTunes Library", key: String = "localMusic")

	var name: String {
		switch self
		{
			case .ListenMoe(let name, _):  return name
			case .LocalMusic(let name, _): return name
		}
	}

	var keyedValue: String {
		switch self
		{
			case .ListenMoe(_, let key):  return key
			case .LocalMusic(_, let key): return key
		}
	}

	var description: String {
		self.name
	}

	init?(with: String)
	{
		switch(with)
		{
			case Self.ListenMoe().keyedValue:
				self = .ListenMoe()

			case Self.LocalMusic().keyedValue:
				self = .LocalMusic()

			default:
				return nil
		}
	}
}



enum ShuffleBehaviour : Hashable, KeyedEnum, CustomStringConvertible
{
	static let values: [Self] = [ .None(), .Random(), .Oldest(), .LeastPlayed() ]

	case None(name: String = "none", key: String = "none")
	case Random(name: String = "random", key: String = "random")
	case Oldest(name: String = "oldest played date", key: String = "oldest")
	case LeastPlayed(name: String = "least play count", key: String = "leastPlayed")

	var name: String {
		switch self
		{
			case .None(let name, _):        return name
			case .Random(let name, _):      return name
			case .Oldest(let name, _):      return name
			case .LeastPlayed(let name, _): return name
		}
	}

	var keyedValue: String {
		switch self
		{
			case .None(_, let key):        return key
			case .Random(_, let key):      return key
			case .Oldest(_, let key):      return key
			case .LeastPlayed(_, let key): return key
		}
	}

	var description: String {
		self.name
	}

	init?(with: String)
	{
		switch(with)
		{
			case Self.None().keyedValue:
				self = .None()

			case Self.Random().keyedValue:
				self = .Random()

			case Self.Oldest().keyedValue:
				self = .Oldest()

			case Self.LeastPlayed().keyedValue:
				self = .LeastPlayed()

			default:
				return nil
		}
	}
}

