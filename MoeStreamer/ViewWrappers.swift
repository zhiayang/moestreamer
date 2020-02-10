// ViewWrappers.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import SwiftUI
import Foundation

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
	@Binding var value: Double

	func makeNSView(context: Context) -> NSSlider
	{
		let slider = NSSlider(value: self.value, minValue: 0, maxValue: 100,
							  target: context.coordinator, action: #selector(Coordinator.valueChanged(_:)))
		return slider
	}

	func updateNSView(_ view: NSSlider, context: Context)
	{
		view.doubleValue = self.value
	}

	class Coordinator : NSObject
	{
		var value: Binding<Double>

		init(value: Binding<Double>)
		{
			self.value = value
		}

		@objc func valueChanged(_ sender: NSSlider)
		{
			self.value.wrappedValue = sender.doubleValue
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(value: $value)
	}
}


struct ActivityIndicator : NSViewRepresentable
{
	public typealias Context = NSViewRepresentableContext<Self>
	public typealias NSViewType = NSProgressIndicator

	public func makeNSView(context: Context) -> NSViewType
	{
		let nsView = NSProgressIndicator()
		nsView.isIndeterminate = true
		nsView.controlSize = .mini
		nsView.style = .spinning

		return nsView
	}

	public func updateNSView(_ nsView: NSViewType, context: Context)
	{
		nsView.startAnimation(self)
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
