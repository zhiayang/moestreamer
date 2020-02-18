// ActivityIndicator.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import SwiftUI
import Foundation

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
