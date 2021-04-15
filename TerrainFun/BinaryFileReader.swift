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
//		pointer.initialize(repeating: 0, count: 1)
		defer
		{
//			pointer.deinitialize(count: 1)
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
