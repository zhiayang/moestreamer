// Logger.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Deque
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

	var lines: Deque<LogItem> = [ ]
	var msgRepeatCount: Int = 1
	var dispatcher = DispatchQueue(label: "logger")

	init()
	{

	}

	func clear()
	{
		self.lines = [ ]
	}

	func getLines() -> Deque<LogItem>
	{
		return self.lines
	}

	func getMsgRepeatCount() -> Int
	{
		return self.msgRepeatCount
	}


	func add(_ item: LogItem)
	{
		dispatcher.async {
			if let last = self.lines.last, last == item
			{
				self.msgRepeatCount += 1
			}
			else
			{
				if self.msgRepeatCount > 1 {
					self.lines.append(.Log(sender: nil, msg: "(repeated \(self.msgRepeatCount) times)"))
				}

				self.msgRepeatCount = 1
				self.lines.append(item)
			}

			if self.lines.count > Settings.get(.logLinesRetain()) {
				_ = self.lines.removeFirst()
			}
		}
	}

	static func log(_ id: String, msg: String, withView: ViewModel? = nil)
	{
		let x = LogItem.Log(sender: id, msg: msg)
		print(x.string())

		Logger.instance.add(x)
		if let vw = withView {
			vw.setStatus(s: x.message(), timeout: 1.5)
		}
	}

	static func log(msg: String, withView: ViewModel? = nil)
	{
		let x = LogItem.Log(sender: nil, msg: msg)
		print(x.string())

		Logger.instance.add(x)
		if let vw = withView {
			vw.setStatus(s: x.message(), timeout: 1.5)
		}
	}



	static func error(_ id: String, msg: String, withView: ViewModel? = nil)
	{
		let x = LogItem.Error(sender: id, msg: msg)
		print(x.string())

		Logger.instance.add(x)
		if let vw = withView {
			vw.setStatus(s: x.message(), timeout: 3.0)
		}
	}

	static func error(msg: String, withView: ViewModel? = nil)
	{
		let x = LogItem.Error(sender: nil, msg: msg)
		print(x.string())

		Logger.instance.add(x)
		if let vw = withView {
			vw.setStatus(s: x.message(), timeout: 3.0)
		}
	}
}

