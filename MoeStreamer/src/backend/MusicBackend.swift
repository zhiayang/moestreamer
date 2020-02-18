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
	static let values: [MusicBackend] = [ .ListenMoe(), .LocalMusic() ]

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
