// Settings.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import Foundation
import KeychainSwift

enum SettingKey : Hashable
{
	case shouldAutoRefresh(key: String = "refreshMetadataOnOpen", default: Bool = true)
	case shouldNotifySongChange(key: String = "notifyOnSongChange", default: Bool = false)
	case shouldUseMediaKeys(key: String = "useMediaKeys", default: Bool = false)
	case shouldResumeOnWake(key: String = "resumeOnWake", default: Bool = false)
	case shouldUpdateNowPlaying(key: String = "updateNowPlaying", default: Bool = false)
	case shouldUseDiscordPresence(key: String = "discordRichPresence", default: Bool = false)
	case shouldPreventIdleSleep(key: String = "preventIdleSleep", default: Bool = false)

	case audioMuted(key: String = "muted", default: Bool = false)
	case audioVolume(key: String = "volume", default: Int = 50)
	case audioVolumeScale(key: String = "volumeScale", default: Int = 100)

	case listenMoeUsername(key: String = "listenMoe_username", default: String = "")
	case listenMoePassword(key: String = "listenMoe_password", default: String = "")
	case listenMoeAutoLogin(key: String = "listenMoe_automaticallyLogin", default: Bool = true)

	case localMusicPlaylist(key: String = "localMusic_playlist", default: String = "")
	case localMusicShuffle(key: String = "localMusic_shuffle", default: ShuffleBehaviour = .Random())

	case statSongsPlayed(key: String = "stat_songsPlayed", default: Int = 0)

	case streamBufferMs(key: String = "streamBufferMilliseconds", default: Int = 2000)
	case logLinesRetain(key: String = "logLinesRetain", default: Int = 200)

	case musicBackend(key: String = "musicBackend", default: MusicBackend = .LocalMusic())
	case settingsSection(key: String = "settingsSection", default: SettingsSection = .LocalMusic)

	case discordAppId(key: String = "discordAppId", default: String = "")
	case discordUserToken(key: String = "discordUserToken", default: String = "")
	case discordAutoFetchToken(key: String = "discordAutoFetchToken", default: Bool = true)

	case ikuraEnabled(key: String = "ikuraEnabled", default: Bool = false)
	case ikuraConsoleIp(key: String = "ikuraConsoleIp", default: String = "")
	case ikuraConsolePort(key: String = "ikuraConsolePort", default: Int = 6969)
	case ikuraConsolePassword(key: String = "ikuraConsolePassword", default: String = "")
	case ikuraWhitelistedSSIDs(key: String = "ikuraWhitelistedSSIDs", default: String = "")

	var key: String {
		switch self
		{
			case .shouldAutoRefresh(let key, _):            return key
			case .shouldNotifySongChange(let key, _):       return key
			case .shouldUseMediaKeys(let key, _):           return key
			case .shouldResumeOnWake(let key, _):           return key
			case .shouldUpdateNowPlaying(let key, _):       return key
			case .shouldUseDiscordPresence(let key, _):     return key
			case .shouldPreventIdleSleep(let key, _):       return key
			case .audioMuted(let key, _):                   return key
			case .audioVolume(let key, _):                  return key
			case .audioVolumeScale(let key, _):             return key
			case .listenMoeUsername(let key, _):            return key
			case .listenMoePassword(let key, _):            return key
			case .listenMoeAutoLogin(let key, _):           return key
			case .localMusicPlaylist(let key, _):           return key
			case .localMusicShuffle(let key, _):            return key
			case .statSongsPlayed(let key, _):              return key
			case .streamBufferMs(let key, _):               return key
			case .logLinesRetain(let key, _):               return key
			case .musicBackend(let key, _):                 return key
			case .settingsSection(let key, _):              return key
			case .discordUserToken(let key, _):             return key
			case .discordAppId(let key, _):                 return key
			case .discordAutoFetchToken(let key, _):        return key
			case .ikuraEnabled(let key, _):                 return key
			case .ikuraConsoleIp(let key, _):               return key
			case .ikuraConsolePort(let key, _):             return key
			case .ikuraConsolePassword(let key, _):         return key
			case .ikuraWhitelistedSSIDs(let key, _):        return key
		}
	}

	var defaultValue: Any {
		switch self
		{
			case .shouldAutoRefresh(_, let def):            return def
			case .shouldNotifySongChange(_, let def):       return def
			case .shouldUseMediaKeys(_, let def):           return def
			case .shouldResumeOnWake(_, let def):           return def
			case .shouldUpdateNowPlaying(_, let def):       return def
			case .shouldUseDiscordPresence(_, let def):     return def
			case .shouldPreventIdleSleep(_, let def):       return def
			case .audioMuted(_, let def):                   return def
			case .audioVolume(_, let def):                  return def
			case .audioVolumeScale(_, let def):             return def
			case .listenMoeUsername(_, let def):            return def
			case .listenMoePassword(_, let def):            return def
			case .listenMoeAutoLogin(_, let def):           return def
			case .localMusicPlaylist(_, let def):           return def
			case .localMusicShuffle(_, let def):            return def
			case .statSongsPlayed(_, let def):              return def
			case .streamBufferMs(_, let def):               return def
			case .logLinesRetain(_, let def):               return def
			case .musicBackend(_, let def):                 return def
			case .settingsSection(_, let def):              return def
			case .discordUserToken(_, let def):             return def
			case .discordAppId(_, let def):                 return def
			case .discordAutoFetchToken(_, let def):        return def
			case .ikuraEnabled(_, let def):                 return def
			case .ikuraConsoleIp(_, let def):               return def
			case .ikuraConsolePort(_, let def):             return def
			case .ikuraConsolePassword(_, let def):         return def
			case .ikuraWhitelistedSSIDs(_, let def):        return def
		}
	}

	var name: String {
		return Mirror(reflecting: self).children.first?.label ?? String(describing: self)
	}
}

class Settings
{
	private static var runningId: Int = 0
	private static var observers: [SettingKey: [(Int, (SettingKey) -> Void)]] = [:]

	static func get<T>(_ key: SettingKey) -> T
	{
		return (UserDefaults.standard.object(forKey: key.key) as? T) ?? (key.defaultValue as! T)
	}

	static func set<T>(_ key: SettingKey, value: T)
	{
		UserDefaults.standard.set(value, forKey: key.key)

		for cb in observers[key] ?? [] {
			cb.1(key)
		}
	}

	static func notifyObservers(for key: SettingKey)
	{
		for cb in observers[key] ?? [] {
			cb.1(key)
		}
	}

	static func observe(_ key: SettingKey, callback: @escaping (SettingKey) -> Void) -> Any
	{
		observers[key, default: []].append((runningId, callback))
		defer { runningId += 1 }

		return runningId
	}

	static func unobserve(_ key: SettingKey, token: Any)
	{
		guard observers[key] != nil else {
			return
		}

		guard let token = token as? Int else {
			return
		}

		for i in 0 ..< observers[key]!.count
		{
			let obs = observers[key]![i]
			if obs.0 == token {
				observers[key]!.remove(at: i)
			}
		}
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
