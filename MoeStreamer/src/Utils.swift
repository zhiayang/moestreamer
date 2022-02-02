// Utils.swift
// Copyright (c) 2022, zhiayang
// SPDX-License-Identifier: Apache-2.0

import Foundation

extension Comparable
{
	func clamped(from min: Self, to max: Self) -> Self
	{
		return (self < min ? min : (self > max ? max : self))
	}
}
