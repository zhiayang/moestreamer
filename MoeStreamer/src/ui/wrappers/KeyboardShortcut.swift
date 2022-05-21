// KeyboardShortcut.swift
// Copyright (c) 2022, zhiayang
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Foundation

extension Backport
{
	@ViewBuilder func keyboardShortcut(key: Character) -> some View
	{
		if #available(macOS 11.0, *)
		{
			content.keyboardShortcut(KeyEquivalent(key), modifiers: [])
		}
		else
		{
			self.content
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
				Button(action: self.action) {
					EmptyView()
				}
				.montereyCompat
				.keyboardShortcut(key: key)
				.buttonStyle(.borderless)
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
