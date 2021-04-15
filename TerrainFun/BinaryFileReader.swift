//
//  BinaryFileReader.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-14.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import Foundation
import System


/**
	A note on endianness:
	
	In all likelihood, Swift will never run on a big-endian platform. This is really too bad,
	because little endian sucks. But knowing the compiler’s endianness can help us avoid
	unnecessary thrashing over the data. Still, I hate the thought of this kind of potential
	bug, so the code either always swaps endianness, or is conditionalized with `#if _endian(big)`.
	According to this [post](https://forums.swift.org/t/does-an-unnecessary-fixedwidthinteger-big-littleendian-get-optimized-away/47420/2),
	a single unnecessary `FixedWidthInteger` swap should be optimized away. An array map
	will not.
	
*/

//	TODO: Reads assert if not enough bytes are read. This is not good. We should throw an error and
//		treat it as a corrupt file.

class
BinaryFileReader
{
	init(url inURL: URL)
		throws
	{
		let fp = FilePath(inURL)!
		let fd = try FileDescriptor.open(fp, .readOnly)	//	TODO: How do I close this?
		self.fd = fd
		
		//	Determine the file length…
		//	TODO: is there a better way?
		
		let end = try self.fd.seek(offset: 0, from: .end)
		self.length = end
		try self.fd.seek(offset: 0, from: .start)
	}
	
	deinit
	{
		try? self.fd.close()
	}
	
//	func
//	seek(by inDelta: Int64)
//	{
//		precondition(self.idx + inDelta >= 0 && self.idx + inDelta < self.length, "seek(by: \(inDelta)) out of bounds")
//		self.idx += inDelta
//	}
//
	func
	seek(to inOffset: Int64)
		throws
	{
		precondition(inOffset >= 0 && inOffset < self.length, "seek(to: \(inOffset)) out of bounds")
		try self.fd.seek(offset: inOffset, from: .start)
	}

//	func
//	seek(to inOffset: UInt64)
//	{
//		precondition(inOffset >= 0 && inOffset < self.length, "seek(to: \(inOffset)) out of bounds")
//		self.idx = Int(inOffset)
//	}
//
//	func
//	seek(to inOffset: UInt32)
//	{
//		seek(to: Int(inOffset))
//	}

	func
	at<ReturnType>(offset inOffset: Int64, op inOp: () throws -> ReturnType)
		throws
		-> ReturnType
	{
		let saveIdx = try self.fd.seek(offset: 0, from: .current)
		defer { try? seek(to: saveIdx) }		//	TODO: handle this error better.
		try seek(to: inOffset)
		return try inOp()
	}
	
	/**
	*/
	
	func
	read(fromAbsoluteOffset inOffset: Int64, into inBuf: UnsafeMutableRawBufferPointer)
		throws
		-> Int
	{
		return try self.fd.read(fromAbsoluteOffset: inOffset, into: inBuf)
	}
	
	func
	get<T>()
		throws
		-> T where T : FixedWidthInteger
	{
		let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
		pointer.initialize(repeating: 0, count: 1)
		defer
		{
			pointer.deinitialize(count: 1)
			pointer.deallocate()
		}
		
		let buf = UnsafeMutableRawBufferPointer(start: pointer, count: MemoryLayout<T>.size)
		let bytesRead = try self.fd.read(into: buf)
		assert(bytesRead == MemoryLayout<T>.size)
		
		//	Swap bytes if needed…
		
		if self.bigEndian
		{
			return T(bigEndian: pointer.pointee)
		}
		else
		{
			return T(littleEndian: pointer.pointee)
		}
	}
	
	func
	get<T: FixedWidthInteger>(_ outArray: inout [T])
		throws
	{
		let bytesRead = try outArray.withUnsafeMutableBytes{ (inBuf) -> Int in
			let bytesRead = try self.fd.read(into: inBuf)
			return bytesRead
		}
		assert(bytesRead == MemoryLayout<T>.size * outArray.count)
		
		//	Swap bytes if needed…
		
	#if _endian(big)			//	Avoid unecessary swaps. See note on class comment.
		if !self.bigEndian
		{
			outArray = outArray.map { T(littleEndian: $0) }
		}
	#else
		if self.bigEndian
		{
			outArray = outArray.map { T(bigEndian: $0) }
		}
	#endif
	}
	
	func
	get<T>(count inCount: Int)
		throws
		-> [T] where T : FixedWidthInteger
	{
		var iv = [T](repeating:0, count: inCount)
		let bytesRead = try iv.withUnsafeMutableBytes{ (inBuf) -> Int in
			let bytesRead = try self.fd.read(into: inBuf)
			return bytesRead
		}
		assert(bytesRead == MemoryLayout<T>.size * iv.count)
		
		//	Swap bytes if needed…
		
	#if _endian(big)			//	Avoid unecessary swaps. See note on class comment.
		if !self.bigEndian
		{
			iv = iv.map { T(littleEndian: $0) }
		}
	#else
		if self.bigEndian
		{
			iv = iv.map { T(bigEndian: $0) }
		}
	#endif
		return iv
	}
	
	
	@inlinable
	func
	get()
		throws
		-> Float
	{
		let iv: UInt32 = try get()
		let fv = Float(bitPattern: iv)
		return fv
	}
	
	@inlinable
	func
	get()
		throws
		-> Double
	{
		let iv: UInt64 = try get()
		let fv = Double(bitPattern: iv)
		return fv
	}

	/**
		Read count Doubles at the current offset.
	*/
	
	@inlinable
	func
	get(count inCount: Int, swapIfNeeded inSwap: Bool = true)
		throws
		-> [Double]
	{
		precondition(inCount >= 0)
		
		if inSwap
		{
			var iv = [UInt64](repeating: 0, count: inCount)
			try get(&iv)
			
			//	The data returned above has already been byte-swapped,
			//	so just make them Doubles…
			
			return iv.map { Double(bitPattern: UInt64(bigEndian: $0)) }
		}
		else
		{
			//	If we  know we don’t have to swap, we can read directly into an
			//	array of Double…
			
			var iv = [Double](repeating: 0, count: inCount)
			let bytesRead = try iv.withUnsafeMutableBytes{ (inBuf) -> Int in
				let bytesRead = try self.fd.read(into: inBuf)
				return bytesRead
			}
			assert(bytesRead == MemoryLayout<Double>.size * inCount)
			return iv
		}
	}

//	func
//	get<T>()
//		throws
//		-> T where T : BinaryFloatingPoint
//	{
//		let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
//		pointer.initialize(repeating: 0, count: 1)
//		defer
//		{
//			pointer.deinitialize(count: 1)
//			pointer.deallocate()
//		}
//
//		let buf = UnsafeMutableRawBufferPointer(start: pointer, count: MemoryLayout<T>.size)
//		//let buf = UnsafeMutableRawBufferPointer.allocate(byteCount: MemoryLayout<T>.stride, alignment: MemoryLayout<T>.alignment)
//		let bytesRead = try self.fd.read(into: buf)
//		assert(bytesRead == MemoryLayout<T>.size)
//
//		if self.bigEndian
//		{
//			return T(bigEndian: pointer.pointee)
//		}
//		else
//		{
//			return T(littleEndian: pointer.pointee)
//		}
//	}
	
//	mutating
//	func
//	getUInt16()
//		-> UInt16
//	{
//		get()
//	}
	
//	@inlinable
//	//mutating
//	func
//	get()
//		-> UInt64
//	{
//		let v: UInt64
//		if self.bigEndian
//		{
//			let hi: UInt32 = self.get()
//			let lo: UInt32 = self.get()
//			v = UInt64(hi) << 32 | UInt64(lo)
//		}
//		else
//		{
//			let lo: UInt32 = self.get()
//			let hi: UInt32 = self.get()
//			v = UInt64(hi) << 32 | UInt64(lo)
//		}
//		return v
//	}
//
//	@inlinable
//	//mutating
//	func
//	get()
//		-> UInt32
//	{
//		let v: UInt32
//		if self.bigEndian
//		{
//			v = UInt32(self.data[self.idx]) << 24
//				| UInt32(self.data[self.idx + 1]) << 16
//				| UInt32(self.data[self.idx + 2]) << 8
//				| UInt32(self.data[self.idx + 3])
//		}
//		else
//		{
//			v = UInt32(self.data[self.idx]) << 0
//				| UInt32(self.data[self.idx + 1]) << 8
//				| UInt32(self.data[self.idx + 2]) << 16
//				| UInt32(self.data[self.idx + 3]) << 24
//		}
//		self.idx += 4
//		return v
//	}
//
//	@inlinable
//	//mutating
//	func
//	get()
//		-> UInt16
//	{
//		let v: UInt16
//		if self.bigEndian
//		{
//			v = UInt16(self.data[self.idx]) << 8
//				| UInt16(self.data[self.idx + 1])
//		}
//		else
//		{
//			v = UInt16(self.data[self.idx]) << 0
//				| UInt16(self.data[self.idx + 1]) << 8
//		}
//		self.idx += 2
//		return v
//	}
//
//	@inlinable
//	//mutating
//	func
//	get()
//		-> UInt8
//	{
//		let v = UInt8(self.data[idx])
//		self.idx += 1
//		return v
//	}
	
//	@inlinable
//	func
//	get()
//		-> Float
//	{
//		let v: Float
//		if self.bigEndian
//		{
//			let iv = UInt32(self.data[self.idx + 4]) << 24
//					| UInt32(self.data[self.idx + 5]) << 16
//					| UInt32(self.data[self.idx + 6]) << 8
//					| UInt32(self.data[self.idx + 7]) << 0
//
//			v = Float(bitPattern: iv)
//		}
//		else
//		{
//			let iv = UInt32(self.data[self.idx + 4]) << 32
//					| UInt32(self.data[self.idx + 5]) << 40
//					| UInt32(self.data[self.idx + 6]) << 48
//					| UInt32(self.data[self.idx + 7]) << 56
//
//			v = Float(bitPattern: iv)
//		}
//		self.idx += 4
//		return v
//	}
//
//	@inlinable
//	//mutating
//	func
//	get()
//		-> Double
//	{
//		let v: Double
//		if self.bigEndian
//		{
//			var iv = UInt64(self.data[self.idx]) << 56
//					| UInt64(self.data[self.idx + 1]) << 48
//					| UInt64(self.data[self.idx + 2]) << 40
//					| UInt64(self.data[self.idx + 3]) << 32
//
//			iv |= UInt64(self.data[self.idx + 4]) << 24
//					| UInt64(self.data[self.idx + 5]) << 16
//					| UInt64(self.data[self.idx + 6]) << 8
//					| UInt64(self.data[self.idx + 7]) << 0
//
//			v = Double(bitPattern: iv)
//		}
//		else
//		{
//			var iv = UInt64(self.data[self.idx]) << 0
//					| UInt64(self.data[self.idx + 1]) << 8
//					| UInt64(self.data[self.idx + 2]) << 16
//					| UInt64(self.data[self.idx + 3]) << 24
//
//			iv |= UInt64(self.data[self.idx + 4]) << 32
//					| UInt64(self.data[self.idx + 5]) << 40
//					| UInt64(self.data[self.idx + 6]) << 48
//					| UInt64(self.data[self.idx + 7]) << 56
//
//			v = Double(bitPattern: iv)
//		}
//		self.idx += 8
//		return v
//	}
//
//	func
//	get(count inCount: UInt64)
//		-> String?
//	{
//		let r = self.idx ..< self.idx + Int(inCount)
//		let s = String(data: self.data[r], encoding: .ascii)
//		return s
//	}

	func
	get(count inCount: Int)
		throws
		-> String?
	{
		var bytes = Data(repeating: 0, count: inCount)
		let bytesRead = try bytes.withUnsafeMutableBytes{ (inBuf) -> Int in
			let bytesRead = try self.fd.read(into: inBuf)
			return bytesRead
		}
		assert(bytesRead == inCount)
		
		let s = String(data: bytes, encoding: .ascii)
		return s
	}
	
	
	@usableFromInline	let fd				:	FileDescriptor
	@usableFromInline	var length			:	Int64
	@usableFromInline	var idx				:	Int64						{ get { return try! self.fd.seek(offset: 0, from: .current) } }		//	TODO: getting the position like this should never fail, right?
	@usableFromInline	var bigEndian							=	true
}

/**
	Array readers.
*/

//extension
//BinaryFileReader
//{
//	/**
//		Read count UInt16s at the current offset.
//	*/
//
//	@inlinable
//	//mutating
//	func
//	get(count inCount: UInt64)
//		-> [UInt16]
//	{
//		precondition(inCount < Int.max)		//	Throw exception?
//
//		var result = [UInt16](repeating: 0, count: Int(inCount))
//		for idx in 0..<Int(inCount)
//		{
//			result[idx] = get()
//		}
//
//		return result
//	}
//
//	/**
//		Read count UInt32s at the current offset.
//	*/
//
//	@inlinable
//	//mutating
//	func
//	get(count inCount: UInt64)
//		-> [UInt32]
//	{
//		precondition(inCount < Int.max)		//	Throw exception?
//
//		var result = [UInt32](repeating: 0, count: Int(inCount))
//		for idx in 0..<Int(inCount)
//		{
//			result[idx] = get()
//		}
//
//		return result
//	}
//
//	/**
//		Read count UInt64s at the current offset.
//	*/
//
//	@inlinable
//	//mutating
//	func
//	get(count inCount: UInt64)
//		-> [UInt64]
//	{
//		precondition(inCount < Int.max)		//	Throw exception?
//
//		var result = [UInt64](repeating: 0, count: Int(inCount))
//		for idx in 0..<Int(inCount)
//		{
//			result[idx] = get()
//		}
//
//		return result
//	}
//
//	/**
//		Read count Doubles at the current offset.
//	*/
//
//	@inlinable
//	//mutating
//	func
//	get(count inCount: UInt64)
//		-> [Double]
//	{
//		precondition(inCount < Int.max)		//	Throw exception?
//
//		var result = [Double](repeating: 0, count: Int(inCount))
//		for idx in 0..<Int(inCount)
//		{
//			result[idx] = get()
//		}
//
//		return result
//	}
//}
