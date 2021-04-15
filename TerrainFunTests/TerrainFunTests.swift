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
import System

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
	testFullLoadTime()
		throws
	{
		let url = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/Mars_HRSC_MOLA_BlendDEM_Global_200mp_v2.tif")
		let fp = FilePath(url)!
		let fd = try FileDescriptor.open(fp, .readOnly)	//	TODO: How do I close this?
		let length = 4//1 * 1 * 1024 * 1024//Int(try fd.seek(offset: 0, from: .end))
		let buf = UnsafeMutableRawBufferPointer.allocate(byteCount: length, alignment: MemoryLayout<UInt8>.alignment)
		defer { buf.deallocate() }
//		buf.initializeMemory(as: UInt8.self, repeating: 0)
		let readCount = try fd.read(fromAbsoluteOffset: 0, into: buf)
		XCTAssertEqual(readCount, length)
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
		let url = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/Mars_HRSC_MOLA_BlendDEM_Global_200mp_v2.tif")		//	106,694 x 53,347
//		let url = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/Mars_HRSC_MOLA_BlendDEM_Global_200mp_1024.tif")	//	  1,024 x    512
		let ti = try! TIFFImageA(contentsOfURL: url)
		let ip = BigTIFFImageProvider(tiff: ti)
		let ci = CIImage(imageProvider: ip,
							size: Int(ti.ifd!.width), Int(ti.ifd!.height),
							format: .L16,
							colorSpace: nil,
							options: [.providerTileSize : [ 16384, 16384 ]])
		
		let scaleFilter = CIFilter(name: "CILanczosScaleTransform")!
		scaleFilter.setValue(ci, forKey: kCIInputImageKey)
		scaleFilter.setValue(0.05, forKey: kCIInputScaleKey)
		scaleFilter.setValue(1.0, forKey:kCIInputAspectRatioKey)
		let outputImage = scaleFilter.outputImage!
		
		let ctx = CIContext()
//		let image = ctx.createCGImage(outputImage, from: CGRect(x: 11878, y: 53347-19484, width: 4096, height: 4096))
//		let image = ctx.createCGImage(outputImage, from: CGRect(x: 0, y: 0, width: 106694, height: 15000))
		let image = ctx.createCGImage(outputImage, from: outputImage.extent)
		XCTAssertNotNil(image, "")
		
		//	Write the image to disk…
		
		let destURL = URL(fileURLWithPath: "/Users/rmann/Downloads/TestImage.png")
		writeCGImage(image!, to: destURL)
	}
	
	func
	testBinaryFileReaderLE()
	{
		do
		{
			let url = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/Mars_HRSC_MOLA_BlendDEM_Global_200mp_v2.tif")		//	106,694 x 53,347
			let reader = try BinaryFileReader(url: url)
			XCTAssertEqual(reader.length, 11384463908)
			
			let endian: UInt16 = try reader.get()				//	Bytes 0-1 (endian)
			XCTAssertEqual(endian, 0x4949)
			reader.bigEndian = false
			let formatVersion: UInt16 = try reader.get()			//	Bytes 2-3 (format version)
			XCTAssertEqual(formatVersion, 43)
			
			try reader.seek(to: 0)
			var a = [UInt16](repeating: 0, count: 2)
			try reader.get(&a)
			XCTAssertEqual(a[0], 0x4949)
			XCTAssertEqual(a[1], 43)
		}
		
		catch (let e)
		{
			XCTFail("Error testing binary file reader: \(e)")
		}
	}
	
	func
	testBinaryFileReaderBE()
	{
		do
		{
			let url = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/Mars_HRSC_MOLA_BlendDEM_Global_200mp_1024.tif")	//	  1,024 x    512
			let reader = try BinaryFileReader(url: url)
			XCTAssertEqual(reader.length, 529022)
			
			let endian: UInt16 = try reader.get()				//	Bytes 0-1 (endian)
			XCTAssertEqual(endian, 0x4d4d)
			reader.bigEndian = true
			let formatVersion: UInt16 = try reader.get()			//	Bytes 2-3 (format version)
			XCTAssertEqual(formatVersion, 42)
			
			try reader.seek(to: 0)
			var a = [UInt16](repeating: 0, count: 2)
			try reader.get(&a)
			XCTAssertEqual(a[0], 0x4d4d)
			XCTAssertEqual(a[1], 42)
		}
		
		catch (let e)
		{
			XCTFail("Error testing binary file reader: \(e)")
		}
	}
}


@discardableResult func writeCGImage(_ image: CGImage, to destinationURL: URL) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypePNG, 1, nil) else { return false }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}
