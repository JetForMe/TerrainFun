//
//  BinaryReader.swift
//  TerrainFun
//
//  Created by Rick Mann on 2020-07-28.
//  Copyright © 2020 Latency: Zero, LLC. All rights reserved.
//

import Foundation




class
BinaryReader
{
	init(data inData: Data)
	{
		self.data = inData
	}
	
//	mutating
//	func
//	get<T>()
//		-> T where T : FixedWidthInteger
//	{
//		let size = MemoryLayout<T>.stride
//		let v: T = self.data.subdata(in: self.idx..<self.idx + size).withUnsafeBytes { $0.load(as: T.self) }
//		self.idx += size
//		if self.bigEndian
//		{
//			return T(bigEndian: v)
//		}
//		else
//		{
//			return T(littleEndian: v)
//		}
//	}
	
//	mutating
//	func
//	getUInt16()
//		-> UInt16
//	{
//		get()
//	}
	
	@inlinable
	//mutating
	func
	get()
		-> UInt64
	{
		let v: UInt64
		if self.bigEndian
		{
			let hi: UInt32 = self.get()
			let lo: UInt32 = self.get()
			v = UInt64(hi) << 32 | UInt64(lo)
		}
		else
		{
			let lo: UInt32 = self.get()
			let hi: UInt32 = self.get()
			v = UInt64(hi) << 32 | UInt64(lo)
		}
		return v
	}
	
	@inlinable
	//mutating
	func
	get()
		-> UInt32
	{
		let v: UInt32
		if self.bigEndian
		{
			v = UInt32(self.data[self.idx]) << 24
				| UInt32(self.data[self.idx + 1]) << 16
				| UInt32(self.data[self.idx + 2]) << 8
				| UInt32(self.data[self.idx + 3])
		}
		else
		{
			v = UInt32(self.data[self.idx]) << 0
				| UInt32(self.data[self.idx + 1]) << 8
				| UInt32(self.data[self.idx + 2]) << 16
				| UInt32(self.data[self.idx + 3]) << 24
		}
		self.idx += 4
		return v
	}
	
	@inlinable
	//mutating
	func
	get()
		-> UInt16
	{
		let v: UInt16
		if self.bigEndian
		{
			v = UInt16(self.data[self.idx]) << 8
				| UInt16(self.data[self.idx + 1])
		}
		else
		{
			v = UInt16(self.data[self.idx]) << 0
				| UInt16(self.data[self.idx + 1]) << 8
		}
		self.idx += 2
		return v
	}
	
	@inlinable
	//mutating
	func
	get()
		-> Double
	{
		let v: Double
		if self.bigEndian
		{
			var iv = UInt64(self.data[self.idx]) << 56
					| UInt64(self.data[self.idx + 1]) << 48
					| UInt64(self.data[self.idx + 2]) << 40
					| UInt64(self.data[self.idx + 3]) << 32
			
			iv |= UInt64(self.data[self.idx + 4]) << 24
					| UInt64(self.data[self.idx + 5]) << 16
					| UInt64(self.data[self.idx + 6]) << 8
					| UInt64(self.data[self.idx + 7]) << 0
			
			v = Double(bitPattern: iv)
		}
		else
		{
			var iv = UInt64(self.data[self.idx]) << 0
					| UInt64(self.data[self.idx + 1]) << 8
					| UInt64(self.data[self.idx + 2]) << 16
					| UInt64(self.data[self.idx + 3]) << 24
					
			iv |= UInt64(self.data[self.idx + 4]) << 32
					| UInt64(self.data[self.idx + 5]) << 40
					| UInt64(self.data[self.idx + 6]) << 48
					| UInt64(self.data[self.idx + 7]) << 56
			
			v = Double(bitPattern: iv)
		}
		self.idx += 8
		return v
	}
	
	func
	get(count inCount: UInt64)
		-> String?
	{
		let r = self.idx ..< self.idx + Int(inCount)
		let s = String(data: self.data[r], encoding: .ascii)
		return s
	}
	
	//mutating
	func
	seek(by inDelta: Int)
	{
		precondition(self.idx + inDelta >= 0 && self.idx + inDelta < self.data.count, "seek(by: \(inDelta)) out of bounds")
		self.idx += inDelta
	}
	
	//mutating
	func
	seek(to inOffset: Int)
	{
		precondition(inOffset >= 0 && inOffset < self.data.count, "seek(to: \(inOffset)) out of bounds")
		self.idx = inOffset
	}
	
	//mutating
	func
	seek(to inOffset: UInt64)
	{
		precondition(inOffset >= 0 && inOffset < self.data.count, "seek(to: \(inOffset)) out of bounds")
		self.idx = Int(inOffset)
	}
	
	//mutating
	func
	seek(to inOffset: UInt32)
	{
		seek(to: Int(inOffset))
	}
	
	//mutating
	func
	at<ReturnType>(offset inOffset: UInt64, op inOp: () throws -> ReturnType)
		throws
		-> ReturnType
	{
		let saveIdx = self.idx
		defer { seek(to: saveIdx) }
		seek(to: inOffset)
		return try inOp()
	}
	
	@usableFromInline	let data			:	Data
	@usableFromInline	var idx				:	Int			=	0
	@usableFromInline	var bigEndian						=	true
}

/**
	Array readers.
*/

extension
BinaryReader
{
	/**
		Read count UInt16s at the current offset.
	*/
	
	@inlinable
	//mutating
	func
	get(count inCount: UInt64)
		-> [UInt16]
	{
		precondition(inCount < Int.max)		//	Throw exception?
		
		var result = [UInt16](repeating: 0, count: Int(inCount))
		for idx in 0..<Int(inCount)
		{
			result[idx] = get()
		}
		
		return result
	}
	
	/**
		Read count UInt32s at the current offset.
	*/
	
	@inlinable
	//mutating
	func
	get(count inCount: UInt64)
		-> [UInt32]
	{
		precondition(inCount < Int.max)		//	Throw exception?
		
		var result = [UInt32](repeating: 0, count: Int(inCount))
		for idx in 0..<Int(inCount)
		{
			result[idx] = get()
		}
		
		return result
	}
	
	/**
		Read count UInt64s at the current offset.
	*/
	
	@inlinable
	//mutating
	func
	get(count inCount: UInt64)
		-> [UInt64]
	{
		precondition(inCount < Int.max)		//	Throw exception?
		
		var result = [UInt64](repeating: 0, count: Int(inCount))
		for idx in 0..<Int(inCount)
		{
			result[idx] = get()
		}
		
		return result
	}
	
	/**
		Read count Doubles at the current offset.
	*/
	
	@inlinable
	//mutating
	func
	get(count inCount: UInt64)
		-> [Double]
	{
		precondition(inCount < Int.max)		//	Throw exception?
		
		var result = [Double](repeating: 0, count: Int(inCount))
		for idx in 0..<Int(inCount)
		{
			result[idx] = get()
		}
		
		return result
	}
}
