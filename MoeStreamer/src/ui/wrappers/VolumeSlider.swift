// VolumeSlider.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import SwiftUI
import Foundation

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
