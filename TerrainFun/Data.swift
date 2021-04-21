//
//  Data.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-20.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import Foundation




extension
Data
{
	init(unsafeUninitializedCapacity inCapacity: Int,
			initializingWith initializer: (inout UnsafeMutableRawBufferPointer, inout Int) throws -> Void)
		rethrows
	{
		let buffer = UnsafeMutableRawPointer.allocate(byteCount: inCapacity, alignment: MemoryLayout<UInt8>.alignment)
		var bp = UnsafeMutableRawBufferPointer(start: buffer, count: inCapacity)
		let originalAddress = bp.baseAddress
		var count: Int = 0
		defer
		{
			precondition(count <= inCapacity, "Initialized count set to greater than specified capacity.")
			precondition(bp.baseAddress == originalAddress, "Can't reassign buffer in Array(unsafeUninitializedCapacity:initializingWith:)")
		}
		
		do
		{
			try initializer(&bp, &count)
		}
		
		catch (let e)
		{
			//  Ensure the buffer gets deallocated no matter what. Might be better to just deallocate it directly
			self = Data(bytesNoCopy: buffer, count: count, deallocator: .custom({ b,c in b.deallocate() }))
			throw e
		}
		
		self = Data(bytesNoCopy: buffer, count: count, deallocator: .custom({ b,c in b.deallocate() }))
	}
}
