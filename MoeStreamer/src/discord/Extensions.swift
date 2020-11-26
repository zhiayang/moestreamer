// Extensions.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import Socket
import SwiftyJSON
import Foundation

extension Socket
{
	private func send(opcode: Opcode, data: Data) -> Bool
	{
		if !self.isConnected {
			return false
		}

		let buf = UnsafeMutableRawBufferPointer.allocate(byteCount: 8 + data.count, alignment: 1)
		defer { buf.deallocate() }

		buf.storeBytes(of: opcode.rawValue, toByteOffset: 0, as: UInt32.self)
		buf.storeBytes(of: UInt32(data.count), toByteOffset: 4, as: UInt32.self)
		data.copyBytes(to: (buf.baseAddress! + 8).assumingMemoryBound(to: UInt8.self), count: data.count)

		do {
			try self.write(from: buf.baseAddress!, bufSize: buf.count)
			return true
		} catch {
			print("send failed: \((error as? Socket.Error)?.errorReason ?? "unknown error")")
			return false
		}
	}

	func send(opcode: Opcode, msg: String) -> Bool
	{
		return self.send(opcode: opcode, data: msg.data(using: .utf8)!)
	}

	func send(opcode: Opcode, json: JSON) -> Bool
	{
		return self.send(opcode: opcode, data: try! json.rawData(options: []))
	}
}

extension NSImage
{
	func base64Encoded() -> String?
	{
		guard let img = self.copyWithRatioTo(size: NSSize(width: 768, height: 768)) else {
			return nil
		}

		guard let data = NSBitmapImageRep(data: img.tiffRepresentation!)?.representation(using: .jpeg, properties: [:]) else {
			return nil
		}

		return "data:image/jpg;base64,\(data.base64EncodedString())"
	}

	func copyWith(size: NSSize) -> NSImage?
	{
		// Create a new rect with given width and height
		let frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)

		// Get the best representation for the given size.
		guard let rep = self.bestRepresentation(for: frame, context: nil, hints: nil) else {
			return nil
		}

		// Create an empty image with the given size.
		let img = NSImage(size: size)

		// Set the drawing context and make sure to remove the focus before returning.
		img.lockFocus()
		defer { img.unlockFocus() }

		// Draw the new image
		if rep.draw(in: frame) {
			return img
		}

		// Return nil in case something went wrong.
		return nil
	}

	func copyWithRatioTo(size: NSSize) -> NSImage?
	{
		let newSize: NSSize

		let widthRatio  = size.width / self.size.width
		let heightRatio = size.height / self.size.height

		if widthRatio > heightRatio
		{
			newSize = NSSize(width: floor(self.size.width * widthRatio),
							 height: floor(self.size.height * widthRatio))
		}
		else
		{
			newSize = NSSize(width: floor(self.size.width * heightRatio),
							 height: floor(self.size.height * heightRatio))
		}

		return self.copyWith(size: newSize)
	}
}


typealias AlbumHash = UInt64
extension AlbumHash
{
	var hexString: String {
		return String(self, radix: 0x10, uppercase: false)
	}

	static func from<S: StringProtocol>(hexString str: S) -> AlbumHash?
	{
		return AlbumHash(str, radix: 0x10)
	}
}
