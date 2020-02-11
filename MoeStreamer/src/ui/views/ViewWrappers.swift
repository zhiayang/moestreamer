// ViewWrappers.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import SwiftUI
import Foundation

class SavedSettingModel<T> : ObservableObject
{
	private let key: SettingKey
	private let nolog: Bool

	private let getter: (SettingKey) -> T
	private let setter: (SettingKey, T) -> Void

	private let didset: ((T) -> Void)?

	@Published var value: T {
		didSet {
			if !self.nolog {
				Logger.log("config", msg: "set \(self.key.name)=\(self.value)")
			}
			self.setter(self.key, self.value)

			self.didset?(self.value)
		}
	}

	init(_ key: SettingKey, disableLogging: Bool = false,
		 getter: @escaping (SettingKey) -> T = Settings.get,
		 setter: @escaping (SettingKey, T) -> Void = Settings.set,
		 didset: ((T) -> Void)? = nil)
	{
		self.key = key

		self.getter = getter
		self.setter = setter
		self.didset = didset

		self.value = self.getter(self.key)

		self.nolog = disableLogging
	}
}

class ViewWrapper : ObservableObject
{
	@Published var dummy: Bool = false
	@Published var status: String = ""
	@Published var spinning: Int = 0

	func spin()
	{
		self.spinning += 1
	}

	func unspin()
	{
		if self.spinning > 0 { self.spinning -= 1 }
	}

	func setStatus(s: String, timeout: TimeInterval? = nil)
	{
		DispatchQueue.main.async {
			withAnimation(.easeIn(duration: 0.25)) {
				self.status = s
			}
		}

		if let t = timeout {
			// can't update the UI in background threads.
			DispatchQueue.main.asyncAfter(deadline: .now() + t) {
				withAnimation(.easeOut(duration: 0.6)) {
					self.status = ""
				}
			}
		}
	}

	func poke()
	{
		DispatchQueue.main.async {
			self.dummy.toggle()
		}
	}
}

struct VolumeSlider : NSViewRepresentable
{
	@Binding var value: Int

	func makeNSView(context: Context) -> NSSlider
	{
		let slider = NSSlider(value: Double(self.value), minValue: 0, maxValue: 100,
							  target: context.coordinator,
							  action: #selector(Coordinator.valueChanged(_:)))

		return slider
	}

	func updateNSView(_ view: NSSlider, context: Context)
	{
		view.doubleValue = Double(self.value)
	}

	func makeCoordinator() -> Coordinator
	{
		return Coordinator(value: $value)
	}

	final class Coordinator : NSObject
	{
		var value: Binding<Int>

		init(value: Binding<Int>)
		{
			self.value = value
		}

		@objc func valueChanged(_ sender: NSSlider)
		{
			self.value.wrappedValue = Int(sender.doubleValue)
		}
	}
}


struct ActivityIndicator : NSViewRepresentable
{
	public typealias Context = NSViewRepresentableContext<Self>
	public typealias NSViewType = NSProgressIndicator

	private let controlSize: NSControl.ControlSize

	init(size: NSControl.ControlSize = .mini)
	{
		self.controlSize = size
	}

	public func makeNSView(context: Context) -> NSViewType
	{
		let nsView = NSProgressIndicator()
		nsView.isIndeterminate = true
		nsView.controlSize = self.controlSize
		nsView.style = .spinning

		return nsView
	}

	public func updateNSView(_ nsView: NSViewType, context: Context)
	{
		nsView.startAnimation(self)
	}
}

struct BetterTextField<FieldType: NSTextField> : NSViewRepresentable
{
	@Binding var text: String
	@Binding var field: FieldType?

	var placeholder: String
	var changeHandler: ((String, FieldType) -> Void)? = nil
	var finishHandler: ((String, FieldType) -> Void)? = nil
	var enterHandler: ((String, FieldType) -> Void)? = nil

	init(placeholder: String, text: Binding<String>, field: Binding<FieldType?>,
		 onTextChanged: ((String, FieldType) -> Void)? = nil,
		 onFinishEditing: ((String, FieldType) -> Void)? = nil,
		 onEnter: ((String, FieldType) -> Void)? = nil)
	{
		self._text = text
		self._field = field

		self.placeholder = placeholder
		self.changeHandler = onTextChanged
		self.finishHandler = onFinishEditing
		self.enterHandler = onEnter
	}

	func makeNSView(context: Context) -> FieldType
	{
		let textField = FieldType(string: text)

		textField.delegate = context.coordinator
		textField.placeholderString = self.placeholder

		textField.target = context.coordinator
		textField.action = #selector(Coordinator.enterAction(_:))
		textField.cell?.sendsActionOnEndEditing = false

		DispatchQueue.main.async {
			self.field = textField
		}

		return textField
	}

	func updateNSView(_ nsView: FieldType, context: Context)
	{
		nsView.stringValue = text
	}

	func makeCoordinator() -> Coordinator
	{
		return Coordinator(setter: {
			self.text = $0
			self.changeHandler?($0, $1)
		}, finaliser: self.finishHandler, enteriser: self.enterHandler)
	}




	final class Coordinator : NSObject, NSTextFieldDelegate
	{
		var setter: (String, FieldType) -> Void
		var finaliser: ((String, FieldType) -> Void)?
		var enteriser: ((String, FieldType) -> Void)?

		init(setter: @escaping (String, FieldType) -> Void,
			 finaliser: ((String, FieldType) -> Void)?,
			 enteriser: ((String, FieldType) -> Void)?)
		{
			self.setter = setter
			self.finaliser = finaliser
			self.enteriser = enteriser
		}

		func controlTextDidChange(_ obj: Notification)
		{
			if let textField = obj.object as? FieldType {
				setter(textField.stringValue, textField)
			}
		}

		func controlTextDidEndEditing(_ obj: Notification)
		{
			if let textField = obj.object as? FieldType {
				self.finaliser?(textField.stringValue, textField)
			}
		}

		@objc func enterAction(_ sender: AnyObject)
		{
			if let textField = sender as? FieldType {
				self.enteriser?(textField.stringValue, textField)
			}
		}
	}
}

public extension View
{
	func toolTip(_ toolTip: String) -> some View
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
