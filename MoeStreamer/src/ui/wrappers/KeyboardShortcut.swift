// KeyboardShortcut.swift
// Copyright (c) 2022, zhiayang
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Foundation

extension Backport
{
	@ViewBuilder func keyboardShortcut(key: Character) -> some View
	{
		// this shit is broken on ventura (13), and doesn't exist on catalina (10.15)
		if #available(macOS 13.0, *)
		{
			self.content
		}
		else if #unavailable(macOS 11.0)
		{
			self.content
		}
		else
		{
			content.keyboardShortcut(KeyEquivalent(key), modifiers: [])
		}
	}
}

struct ShortcutMaker: View
{
	let shortcuts: [Character]
	let action: () -> Void

	var body: some View {
		ZStack {
			ForEach(self.shortcuts, id: \.self) { key in
				Button(action: { print("AAAAA"); self.action() }) {
					EmptyView()
				}
				.montereyCompat
				.keyboardShortcut(key: key)
//				.buttonStyle(.plain)
				.fixedSize()
				.frame(width: 0.0, height: 0.0)
				.padding(0)
				.clipped()
				.hidden()
			}
		}
		.fixedSize()
		.frame(width: 0.0, height: 0.0)
		.padding(0)
		.clipped()
		.hidden()
	}
}
