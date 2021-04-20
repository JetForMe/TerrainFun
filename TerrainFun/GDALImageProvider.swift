//
//  GDALImageProvider.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-20.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import Foundation




class
GDALImageProvider : CIImageProvider
{
	init(dataset inDS: GDAL.Dataset)
	{
		self.ds = inDS
		self.rb = self.ds.getRasterBand(1)
	}
	
	/**
	*/
	
	@objc
	func
	provideImageData(_ ioData: UnsafeMutableRawPointer,
						bytesPerRow inRowbytes: Int,
						origin inX: Int,
								_ inY: Int,
						size inWidth: Int,
							_ inHeight: Int,
						userInfo inInfo: Any?)
	{
		let startTime = CFAbsoluteTimeGetCurrent()
		debugLog("provideImageData(bytesPerRow: \(inRowbytes); origin: \(inX), \(inY); size: \(inWidth), \(inHeight) @ \(startTime)")
		
		defer
		{
			let endTime = CFAbsoluteTimeGetCurrent()
			let delta = endTime - startTime
			debugLog("  took time: \(delta) @ \(endTime)")
		}
		
		self.rb.rasterRead(into: ioData,
							bufferWidth: inWidth,
							bufferHeight: inHeight,
							xOff: inX, yOff: inY, xSize: inWidth, ySize: inHeight,
							lineSpace: inRowbytes)
	}
	
	let			ds					:	GDAL.Dataset
	let			rb					:	GDAL.RasterBand
}

