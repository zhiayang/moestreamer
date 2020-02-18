// ViewWrappers.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import SwiftUI
import Foundation

class SavedSettingModel<T: Equatable> : ObservableObject
{
	private let key: SettingKey
	private let nolog: Bool

	private let getter: (SettingKey) -> T
	private let setter: (SettingKey, T) -> Void

	private let didset: ((T) -> Void)?
	private let willset: ((T) -> Bool)?

	@Published var value: T {
		didSet {
			if self.value == oldValue {
				return
			}

			if !self.nolog {
				Logger.log("config", msg: "set \(self.key.name)=\(self.value)")
			}
			self.setter(self.key, self.value)

			if self.willset?(self.value) ?? true {
				self.didset?(self.value)
			} else {
				self.value = oldValue
			}
		}
	}

	init(_ key: SettingKey, disableLogging: Bool = false,
		 getter: @escaping (SettingKey) -> T = Settings.get,
		 setter: @escaping (SettingKey, T) -> Void = Settings.set,
		 didset: ((T) -> Void)? = nil, willset: ((T) -> Bool)? = nil)
	{
		self.key = key

		self.getter = getter
		self.setter = setter
		self.didset = didset
		self.willset = willset

		self.value = self.getter(self.key)
		self.nolog = disableLogging
	}
}

protocol ViewModel
{
	func poke()
	func spin()
	func unspin()
	
	func setStatus(s: String, timeout: TimeInterval?)
	func onSongChange(song: Song?)
}

public extension View
{
	func tooltip(_ toolTip: String) -> some View
	{
		self.overlay(TooltipView(toolTip: toolTip))
	}
}

private struct TooltipView : NSViewRepresentable
{
	let toolTip: String

	func makeNSView(context: NSViewRepresentableContext<TooltipView>) -> NSView
	{
		NSView()
	}

	func updateNSView(_ nsView: NSView, context: NSViewRepresentableContext<TooltipView>)
	{
		nsView.toolTip = self.toolTip
	}
}

extension Data
{
	func toString() -> String
	{
		return String(data: self, encoding: .utf8) ?? "<invalid>"
	}
}

extension URLRequest
{
	func dump()
	{
		print("\(httpMethod ?? "") \(self)")
		print("BODY \n \(httpBody!.toString())")
		print("HEADERS \n \(allHTTPHeaderFields!)")
	}
}

protocol OptionalString { }
extension String : OptionalString {}

extension Optional where Wrapped: OptionalString
{
	var isNilOrEmpty: Bool {
		return ((self as? String) ?? "").isEmpty
	}
}


class IntegerNumberFormatter : NumberFormatter
{
	override func isPartialStringValid(_ partial: String,
									   newEditingString: AutoreleasingUnsafeMutablePointer<NSString?>?,
									   errorDescription: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool
	{
		return partial.isEmpty || Int(partial) != nil
	}
}

