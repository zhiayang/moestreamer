// Settings.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import Foundation
import KeychainSwift

enum SettingKey
{
	case shouldAutoRefresh(key: String = "refreshMetadataOnOpen", default: Bool = true)
	case shouldNotifySongChange(key: String = "notifyOnSongChange", default: Bool = false)
	case shouldUseKeyboardShortcuts(key: String = "useKeyboardShortcuts", default: Bool = false)
	case shouldUseMediaKeys(key: String = "useMediaKeys", default: Bool = false)
	case shouldResumeOnWake(key: String = "resumeOnWake", default: Bool = false)

	case audioMuted(key: String = "muted", default: Bool = false)
	case audioVolume(key: String = "volume", default: Int = 50)

	case listenMoeUsername(key: String = "listenMoe_username", default: String = "")
	case listenMoePassword(key: String = "listenMoe_password", default: String = "")
	case listenMoeAutoLogin(key: String = "listenMoe_automaticallyLogin", default: Bool = true)

	case localMusicPlaylist(key: String = "localMusic_playlist", default: String = "")
	case localMusicShuffle(key: String = "localMusic_shuffle", default: ShuffleBehaviour = .Random())

	case statSongsPlayed(key: String = "stat_songsPlayed", default: Int = 0)

	case streamBufferMs(key: String = "streamBufferMilliseconds", default: Int = 2000)
	case logLinesRetain(key: String = "logLinesRetain", default: Int = 200)

	case musicBackend(key: String = "musicBackend", default: MusicBackend = .ListenMoe())

	var key: String {
		switch self
		{
			case .shouldAutoRefresh(let key, _):          return key
			case .shouldNotifySongChange(let key, _):     return key
			case .shouldUseKeyboardShortcuts(let key, _): return key
			case .shouldUseMediaKeys(let key, _):         return key
			case .shouldResumeOnWake(let key, _):         return key
			case .audioMuted(let key, _):                 return key
			case .audioVolume(let key, _):                return key
			case .listenMoeUsername(let key, _):          return key
			case .listenMoePassword(let key, _):          return key
			case .listenMoeAutoLogin(let key, _):         return key
			case .localMusicPlaylist(let key, _):         return key
			case .localMusicShuffle(let key, _):          return key
			case .statSongsPlayed(let key, _):            return key
			case .streamBufferMs(let key, _):             return key
			case .logLinesRetain(let key, _):             return key
			case .musicBackend(let key, _):               return key
		}
	}

	var defaultValue: Any {
		switch self
		{
			case .shouldAutoRefresh(_, let def):          return def
			case .shouldNotifySongChange(_, let def):     return def
			case .shouldUseKeyboardShortcuts(_, let def): return def
			case .shouldUseMediaKeys(_, let def):         return def
			case .shouldResumeOnWake(_, let def):         return def
			case .audioMuted(_, let def):                 return def
			case .audioVolume(_, let def):                return def
			case .listenMoeUsername(_, let def):          return def
			case .listenMoePassword(_, let def):          return def
			case .listenMoeAutoLogin(_, let def):         return def
			case .localMusicPlaylist(_, let def):         return def
			case .localMusicShuffle(_, let def):          return def
			case .statSongsPlayed(_, let def):            return def
			case .streamBufferMs(_, let def):             return def
			case .logLinesRetain(_, let def):             return def
			case .musicBackend(_, let def):               return def
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



	static func getKE<T: KeyedEnum>(_ key: SettingKey) -> T
	{
		if let str = UserDefaults.standard.object(forKey: key.key) as? String {
			return T.init(with: str) ?? (key.defaultValue as! T)
		}

		return key.defaultValue as! T
	}

	static func setKE<T: KeyedEnum>(_ key: SettingKey, value: T)
	{
		UserDefaults.standard.set(value.keyedValue, forKey: key.key)
	}

}
