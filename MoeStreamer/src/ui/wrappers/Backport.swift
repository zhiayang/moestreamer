// Backport.swift
// Copyright (c) 2022, zhiayang
// SPDX-License-Identifier: Apache-2.0

// https://developer.apple.com/forums/thread/689189

import SwiftUI
import Foundation

struct Backport<Content: View>
{
	let content: Content
}

extension View
{
	var montereyCompat: Backport<Self> {
		Backport(content: self)
	}
}
