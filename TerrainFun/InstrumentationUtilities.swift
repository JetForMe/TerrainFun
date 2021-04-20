//
//  InstrumentationUtilities.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-20.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import Foundation




struct
TimeBlock
{
	init()
	{
		self.startTime = CFAbsoluteTimeGetCurrent()
	}
	
	func
	duration()
		-> Double
	{
		let now = CFAbsoluteTimeGetCurrent()
		let dur = now - self.startTime
		return dur
	}
	
	
	let		startTime: Double
}
