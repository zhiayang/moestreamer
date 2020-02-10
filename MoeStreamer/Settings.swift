// Settings.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import Foundation
import KeychainSwift

enum Settings
{
	static func get<T>(key: String, default: T) -> T
	{
		return (UserDefaults.standard.object(forKey: key) as? T) ?? `default`
	}

	static func get<T>(key: String) -> T?
	{
		return UserDefaults.standard.object(forKey: key) as? T
	}

	static func set<T>(key: String, value: T)
	{
		return UserDefaults.standard.set(value, forKey: key)
	}


	static func getKeychain(key: String, default: String) -> String
	{
		let k = KeychainSwift()
		return k.get(key) ?? `default`
	}

	static func setKeychain(key: String, value: String)
	{
		let k = KeychainSwift()
		k.set(value, forKey: key)
	}
}
