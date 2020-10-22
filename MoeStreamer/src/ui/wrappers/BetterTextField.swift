// BetterTextField.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import SwiftUI
import Foundation

struct BetterTextField<FieldType: NSTextField> : NSViewRepresentable
{
	@Binding var text: String
	@Binding var field: FieldType?

	var placeholder: String
	var setupField: ((FieldType) -> Void)? = nil
	var changeHandler: ((String, FieldType) -> Void)? = nil
	var finishHandler: ((String, FieldType) -> Void)? = nil
	var enterHandler: ((String, FieldType) -> Void)? = nil

	init(placeholder: String, text: Binding<String>, field: Binding<FieldType?>,
		 setupField: ((FieldType) -> Void)? = nil,
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
			self.setupField?(self.field!)
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



class CustomSearchField : NSSearchField
{
	override func cancelOperation(_ sender: Any?)
	{
		self.stringValue = ""

		DispatchQueue.main.async {
			// this is kinda hacky...
			self.resignFirstResponder()
			AppDelegate.shared.controller.becomeFirstResponder()
		}
	}
}
