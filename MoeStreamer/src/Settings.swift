// Settings.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import Foundation
import KeychainSwift

enum SettingKey
{
	case shouldAutoLogin(key: String = "automaticallyLogin", default: Bool = true)
	case shouldAutoRefresh(key: String = "refreshMetadataOnOpen", default: Bool = true)
	case shouldNotifySongChange(key: String = "notifyOnSongChange", default: Bool = false)

	case audioMuted(key: String = "muted", default: Bool = false)
	case audioVolume(key: String = "volume", default: Int = 50)

	case listenMoeUsername(key: String = "listenMoe_username", default: String = "")
	case listenMoePassword(key: String = "listenMoe_password", default: String = "")


	var key: String {
		switch self
		{
			case .shouldAutoLogin(let key, _):        return key
			case .shouldAutoRefresh(let key, _):      return key
			case .shouldNotifySongChange(let key, _): return key
			case .audioMuted(let key, _):             return key
			case .audioVolume(let key, _):            return key
			case .listenMoeUsername(let key, _):      return key
			case .listenMoePassword(let key, _):      return key
		}
	}

	var defaultValue: Any {
		switch self
		{
			case .shouldAutoLogin(_, let def):        return def
			case .shouldAutoRefresh(_, let def):      return def
			case .shouldNotifySongChange(_, let def): return def
			case .audioMuted(_, let def):             return def
			case .audioVolume(_, let def):            return def
			case .listenMoeUsername(_, let def):      return def
			case .listenMoePassword(_, let def):      return def
		}
	}

	var name: String {
		return Mirror(reflecting: self).children.first?.label ?? String(describing: self)
	}
}

enum Settings
{
	static func get<T>(_ key: SettingKey) -> T
	{
		return (UserDefaults.standard.object(forKey: key.key) as? T) ?? (key.defaultValue as! T)
	}

	static func set<T>(_ key: SettingKey, value: T)
	{
		return UserDefaults.standard.set(value, forKey: key.key)
	}


	static func getKeychain(_ key: SettingKey) -> String
	{
		let k = KeychainSwift()
		return k.get(key.key) ?? (key.defaultValue as! String)
	}

	static func setKeychain(_ key: SettingKey, value: String)
	{
		let k = KeychainSwift()
		k.set(value, forKey: key.key)
	}
}
