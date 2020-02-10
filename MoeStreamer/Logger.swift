// Logger.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import SwiftUI
import Foundation

enum LogItem : Hashable
{
	case Log(sender: String?, msg: String)
	case Error(sender: String?, msg: String)

	func string() -> String
	{
		switch self
		{
			case let .Log(s, m):   return "\(s == nil ? "" : "[\(s!)] ")\(m)"
			case let .Error(s, m): return "\(s == nil ? "" : "[\(s!)] ")error: \(m)"
		}
	}

	func message() -> String
	{
		switch self
		{
			case let .Log(_, m):   return m
			case let .Error(_, m): return m
		}
	}

	func isError() -> Bool
	{
		switch self
		{
			case .Error: return true
			default:     return false
		}
	}
	
}

class Logger : ObservableObject
{
	public static var instance = Logger()

	@Published var lines: [LogItem] = [ ]

	init()
	{
	}

	func add(_ item: LogItem)
	{
		DispatchQueue.main.async {
			self.lines.append(item)
		}
	}

	static func log(_ id: String, msg: String, withView: ViewWrapper? = nil)
	{
		let x = LogItem.Log(sender: id, msg: msg)
		print(x.string())

		Logger.instance.add(x)
		if let vw = withView {
			vw.setStatus(s: x.message(), timeout: 1.0)
		}
	}

	static func log(msg: String, withView: ViewWrapper? = nil)
	{
		let x = LogItem.Log(sender: nil, msg: msg)
		print(x.string())

		Logger.instance.add(x)
		if let vw = withView {
			vw.setStatus(s: x.message(), timeout: 1.0)
		}
	}



	static func error(_ id: String, msg: String, withView: ViewWrapper? = nil)
	{
		let x = LogItem.Error(sender: id, msg: msg)
		print(x.string())

		Logger.instance.add(x)
		if let vw = withView {
			vw.setStatus(s: x.message(), timeout: 3.0)
		}
	}

	static func error(msg: String, withView: ViewWrapper? = nil)
	{
		let x = LogItem.Error(sender: nil, msg: msg)
		print(x.string())

		Logger.instance.add(x)
		if let vw = withView {
			vw.setStatus(s: x.message(), timeout: 3.0)
		}
	}
}

