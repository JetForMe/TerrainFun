//
//  BinaryReader.swift
//  TerrainFun
//
//  Created by Rick Mann on 2020-07-28.
//  Copyright © 2020 Latency: Zero, LLC. All rights reserved.
//

import Foundation




struct
BinaryReader
{
	init(data inData: Data)
	{
		self.data = inData
	}
	
	mutating
	func
	get<T>()
		-> T where T : FixedWidthInteger
	{
		let size = MemoryLayout<T>.stride
		let v: T = self.data.subdata(in: self.idx..<self.idx + size).withUnsafeBytes { $0.load(as: T.self) }
		self.idx += size
		if self.bigEndian
		{
			return T(bigEndian: v)
		}
		else
		{
			return T(littleEndian: v)
		}
	}
	
	mutating
	func
	getUInt16()
		-> UInt16
	{
		get()
	}
	
	mutating
	func
	getUInt23()
		-> UInt32
	{
		let size = MemoryLayout<UInt32>.stride
		let v: UInt32 = self.data.subdata(in: self.idx..<self.idx + size).withUnsafeBytes { $0.load(as: UInt32.self) }
		self.idx += size
		if self.bigEndian
		{
			return UInt32(bigEndian: v)
		}
		else
		{
			return UInt32(littleEndian: v)
		}
	}
	
	mutating
	func
	seek(by inDelta: Int)
	{
		self.idx += inDelta
		precondition(self.idx >= 0 && self.idx < self.data.count, "seek(by: \(inDelta)) out of bounds")
	}
	
	mutating
	func
	seek(to inOffset: Int)
	{
		precondition(inOffset >= 0 && inOffset < self.data.count, "seek(to: \(inOffset)) out of bounds")
		self.idx = inOffset
	}
	
	mutating
	func
	seek(to inOffset: UInt32)
	{
		seek(to: Int(inOffset))
	}
	
	let data			:	Data
	var idx							=	0
	var bigEndian					=	true
}
