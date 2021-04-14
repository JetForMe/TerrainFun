//
//  TerrainFunTests.swift
//  TerrainFunTests
//
//  Created by Rick Mann on 2020-07-22.
//  Copyright © 2020 Latency: Zero, LLC. All rights reserved.
//

import XCTest
@testable import TerrainFun

import CoreImage


/**
	Example BigTIFF: https://astrogeology.usgs.gov/search/map/Mars/Topography/HRSC_MOLA_Blend/Mars_HRSC_MOLA_BlendDEM_Global_200mp_v2
*/

class
TerrainFunTests: XCTestCase
{

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func
    testReadTIFF()
    	throws
	{
//		let url = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/USGS_13_n36w112.tif")
		let url = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/Mars_HRSC_MOLA_BlendDEM_Global_200mp_v2.tif")
		let ti = try! TIFFImageA(contentsOfURL: url)
		debugLog("Size: \(ti.ifd!.width), \(ti.ifd!.height)")
    }
    
    /**
    	Can CGImage work on BigTIFF GeoTIFF images?
    */
    
    func
    testCGImageReadLargeGeoTIFF()
    {
//		let url = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/USGS_13_n36w112.tif")
 		let url = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/Mars_HRSC_MOLA_BlendDEM_Global_200mp_v2.tif")
		guard
			let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
			let imageMD = CGImageSourceCopyProperties(imageSource, nil),
			let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil),// as? [CFString:Any],
			let img = CGImageSourceCreateImageAtIndex(imageSource, 0, [:] as CFDictionary)
		else
		{
			//	We expect this to fail. If it ever succeeds, we might be out of a job…
			debugLog("Couldn't open image at \(url.path)")
			return
		}
		
		//	Take note if we succeed with reading above. It means support has been added
		//	to the OS, and we should consider re-writing…
		
		XCTFail()
		let _ = (imageMD, metadata, img)		//	Silence compiler warnings
	}
	
	func
	testCIImageProvider()
	{
//		let url = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/Mars_HRSC_MOLA_BlendDEM_Global_200mp_v2.tif")		//	106,694 x 53,347
		let url = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/Mars_HRSC_MOLA_BlendDEM_Global_200mp_1024.tif")	//	  1,024 x    512
		let ti = try! TIFFImageA(contentsOfURL: url)
		let ip = BigTIFFImageProvider(tiff: ti)
		let ci = CIImage(imageProvider: ip, size: Int(ti.ifd!.width), Int(ti.ifd!.height), format: .L16, colorSpace: nil, options: [.providerTileSize : [ 128, 128 ]])
		let ctx = CIContext()
		let image = ctx.createCGImage(ci, from: CGRect(x: 0, y: 0, width: 256.0, height: 256.0))
		XCTAssertNotNil(image, "")
	}
}

