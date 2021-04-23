////
////  TerrainFunTests.swift
////  TerrainFunTests
////
////  Created by Rick Mann on 2020-07-22.
////  Copyright © 2020 Latency: Zero, LLC. All rights reserved.
////
//
//import XCTest
//@testable import TerrainFun
//
//import CoreImage
//import CoreVideo
//import System
//import UniformTypeIdentifiers
//
///**
//	Example BigTIFF: https://astrogeology.usgs.gov/search/map/Mars/Topography/HRSC_MOLA_Blend/Mars_HRSC_MOLA_BlendDEM_Global_200mp_v2
//*/
//
//class
//TerrainFunTests: XCTestCase
//{
//	let marsMola1024 = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/Mars_HRSC_MOLA_BlendDEM_Global_200mp_1024.tif")	//	  1,024 x    512
//	let marsMolaFull = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/Mars_HRSC_MOLA_BlendDEM_Global_200mp_v2.tif")
//	let somewhereInUS = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/USGS_13_n36w112.tif")
//
//    override func setUpWithError() throws {
//        // Put setup code here. This method is called before the invocation of each test method in the class.
//    }
//
//    override func tearDownWithError() throws {
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//    }
//	
//	func
//	testInitDataWithFileRead()
//		throws
//	{
//		let fp = FilePath(self.marsMolaFull)!
//		let fd = try FileDescriptor.open(fp, .readOnly)
//		
//		let blockSize = 4
//		let buffer = UnsafeMutableRawPointer.allocate(byteCount: blockSize, alignment: MemoryLayout<UInt8>.alignment)
//		let bp = UnsafeMutableRawBufferPointer(start: buffer, count: blockSize)
//		let bytesRead = try fd.read(fromAbsoluteOffset: 0, into: bp)
//		let data = Data(bytesNoCopy: buffer, count: blockSize, deallocator: .custom({ b,c in b.deallocate() }))
//		XCTAssertEqual(bytesRead, data.count)
//		print("Data: \(data)")
//		
//		let d2 = try Data(unsafeUninitializedCapacity: blockSize) { (ioBuf, ioCount) in
//			ioCount = try fd.read(fromAbsoluteOffset: 0, into:  ioBuf)
//		}
//		print("D2: \(d2)")
//	}
//	
//	func
//	testInitArrayWithFileRead()
//		throws
//	{
//		let fp = FilePath(self.marsMolaFull)!
//		let fd = try FileDescriptor.open(fp, .readOnly)
//		let count = 1024
//		let values = try [UInt16](unsafeUninitializedCapacity: count)
//						{ (ioBuf: inout UnsafeMutableBufferPointer<UInt16>, ioCount: inout Int) in
//							let buffer = UnsafeMutableRawBufferPointer(ioBuf)
//							let bytesRead = try fd.read(into: buffer)
//							ioCount = bytesRead / MemoryLayout<UInt16>.size
//							//	TODO: Throw unexpectedEOF if ioCount < ioBuf.count
//						}
//		print("Got \(values.count) values: \(values[0]), \(values[1])")
//	}
//	
//	func
//	testLargeReadTime()
//		throws
//	{
//		let fp = FilePath(self.marsMolaFull)!
//		let fd = try FileDescriptor.open(fp, .readOnly)
//		let length = 2 * 1024 * 1024 * 1024 - 1		//	Int32.maxValue is the most we can read
//		let buf = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(length), alignment: MemoryLayout<UInt8>.alignment)
//		defer { buf.deallocate() }
//		let readCount = try fd.read(fromAbsoluteOffset: 0, into: buf)
//		XCTAssertEqual(readCount, Int(length))
//	}
//	
//    func
//    testReadTIFF()
//    	throws
//	{
//		let ti = try! TIFFImageA(contentsOfURL: self.marsMolaFull)
//		debugLog("Size: \(ti.ifd!.width), \(ti.ifd!.height)")
//    }
//    
//    /**
//    	Can CGImage work on BigTIFF GeoTIFF images?
//    */
//    
//    func
//    testCGImageReadLargeGeoTIFF()
//    {
//		guard
//			let imageSource = CGImageSourceCreateWithURL(self.marsMolaFull as CFURL, nil),
//			let imageMD = CGImageSourceCopyProperties(imageSource, nil),
//			let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil),// as? [CFString:Any],
//			let img = CGImageSourceCreateImageAtIndex(imageSource, 0, [:] as CFDictionary)
//		else
//		{
//			//	We expect this to fail. If it ever succeeds, we might be out of a job…
//			debugLog("Couldn't open image at \(self.marsMolaFull.path)")
//			return
//		}
//		
//		//	Take note if we succeed with reading above. It means support has been added
//		//	to the OS, and we should consider re-writing…
//		
//		XCTFail()
//		let _ = (imageMD, metadata, img)		//	Silence compiler warnings
//	}
//	
//	func
//	testCIImageProvider()
//	{
//		let ti = try! TIFFImageA(contentsOfURL: self.marsMolaFull)
//		let ip = BigTIFFImageProvider(tiff: ti)
//		let ci = CIImage(imageProvider: ip,
//							size: Int(ti.ifd!.width), Int(ti.ifd!.height),
//							format: .L16,
//							colorSpace: nil,
//							options: [.providerTileSize : [ 16384, 16384 ]])
//		
//		let scaleFilter = CIFilter(name: "CILanczosScaleTransform")!
//		scaleFilter.setValue(ci, forKey: kCIInputImageKey)
//		scaleFilter.setValue(0.05, forKey: kCIInputScaleKey)
//		scaleFilter.setValue(1.0, forKey:kCIInputAspectRatioKey)
//		let outputImage = scaleFilter.outputImage!
//		
//		let ctx = CIContext()
////		let image = ctx.createCGImage(outputImage, from: CGRect(x: 11878, y: 53347-19484, width: 4096, height: 4096))
////		let image = ctx.createCGImage(outputImage, from: CGRect(x: 0, y: 0, width: 106694, height: 15000))
//		let image = ctx.createCGImage(outputImage, from: outputImage.extent)
//		XCTAssertNotNil(image, "")
//		
//		//	Write the image to disk…
//		
//		let destURL = URL(fileURLWithPath: "/Users/rmann/Downloads/TestImage.png")
//		writeCGImageAsPNG(image!, to: destURL)
//	}
//	
//	func
//	testBinaryFileReaderLE()
//	{
//		do
//		{
//			let reader = try BinaryFileReader(url: self.marsMolaFull)
//			XCTAssertEqual(reader.length, 11384463908)
//			
//			let endian: UInt16 = try reader.get()				//	Bytes 0-1 (endian)
//			XCTAssertEqual(endian, 0x4949)
//			reader.bigEndian = false
//			let formatVersion: UInt16 = try reader.get()			//	Bytes 2-3 (format version)
//			XCTAssertEqual(formatVersion, 43)
//			
//			try reader.seek(to: 0)
//			var a = [UInt16](repeating: 0, count: 2)
//			try reader.get(&a)
//			XCTAssertEqual(a[0], 0x4949)
//			XCTAssertEqual(a[1], 43)
//		}
//		
//		catch (let e)
//		{
//			XCTFail("Error testing binary file reader: \(e)")
//		}
//	}
//	
//	func
//	testBinaryFileReaderBE()
//	{
//		do
//		{
//			let reader = try BinaryFileReader(url: self.marsMola1024)
//			XCTAssertEqual(reader.length, 529022)
//			
//			let endian: UInt16 = try reader.get()				//	Bytes 0-1 (endian)
//			XCTAssertEqual(endian, 0x4d4d)
//			reader.bigEndian = true
//			let formatVersion: UInt16 = try reader.get()			//	Bytes 2-3 (format version)
//			XCTAssertEqual(formatVersion, 42)
//			
//			try reader.seek(to: 0)
//			var a = [UInt16](repeating: 0, count: 2)
//			try reader.get(&a)
//			XCTAssertEqual(a[0], 0x4d4d)
//			XCTAssertEqual(a[1], 42)
//		}
//		
//		catch (let e)
//		{
//			XCTFail("Error testing binary file reader: \(e)")
//		}
//	}
//	
//	func
//	testGDALWrapper()
//	{
//		let s = GDAL.versionInfo("RELEASE_NAME")
//		XCTAssertEqual(s, "3.2.2")
//		
//		GDAL.allRegister()
//		let ds = GDAL.Dataset(path: self.marsMolaFull.path)!
////		let txfm = (try? ds.getGeoTransform()) ?? GDAL.GeoTransform()
////		debugLog("Txfm: \(txfm)")
//		let width = ds.xSize
//		let height = ds.ySize
//		XCTAssertEqual(width, 106694)
//		XCTAssertEqual(height, 53347)
//		
//		let bandCount = ds.rasterCount
//		XCTAssertEqual(bandCount, 1)
//		
//		let band = ds.getRasterBand(1)
//		let w = band.xSize
//		let h = band.ySize
//		XCTAssertEqual(w, 106694)
//		XCTAssertEqual(h, 53347)
//		let oc = band.overviewCount
//		XCTAssertEqual(oc, 0)
//		
//		let (bsX, bsY) = band.blockSize
//		XCTAssertEqual(bsX, 106694)
//		XCTAssertEqual(bsY, 1)
//		
//		let (min, max) = band.computeMinMax(approxOK: true)
//		debugLog("Min-max: \(min) - \(max)")
//	}
//	
//	func
//	testCIImageGDALProvider()
//	{
//		GDAL.allRegister()
//		
//		let dss = GDAL.Dataset(path: self.marsMolaFull.path)
//		guard let ds = dss else { XCTFail(); return }
//		
//		let ip = GDALImageProvider(dataset: ds)
//		let ci = CIImage(imageProvider: ip,
//							size: Int(ds.xSize), Int(ds.ySize),
//							format: .L16,
//							colorSpace: nil,
//							options: [.providerTileSize : [ 16384, 16384 ]])
//		
////		let scaleFilter = CIFilter(name: "CILanczosScaleTransform")!
////		scaleFilter.setValue(0.05, forKey: kCIInputScaleKey)
////		scaleFilter.setValue(1.0, forKey:kCIInputAspectRatioKey)
//
//		let scaleFilter = CIFilter(name: "CIAffineTransform")!
//		scaleFilter.setValue(CGAffineTransform(a: 0.05, b: 0.0, c: 0.0, d: 0.05, tx: 0.0, ty: 0.0), forKey: kCIInputTransformKey)
//		
//		
//		scaleFilter.setValue(ci, forKey: kCIInputImageKey)
//		let outputImage = scaleFilter.outputImage!
//		
//		let ctx = CIContext()
////		let image = ctx.createCGImage(outputImage, from: CGRect(x: 11878, y: 53347-19484, width: 4096, height: 4096))
////		let image = ctx.createCGImage(outputImage, from: CGRect(x: 0, y: 0, width: 106694, height: 15000))
//		let image = ctx.createCGImage(outputImage, from: outputImage.extent)
//		XCTAssertNotNil(image, "")
//		
//		//	Write the image to disk…
//		
//		let destURL = URL(fileURLWithPath: "/Users/rmann/Downloads/TestImage.png")
//		writeCGImageAsPNG(image!, to: destURL)
//	}
//	
//	func
//	testDirectGDALRead()
//	{
//		GDAL.allRegister()
//		let dss = GDAL.Dataset(path: self.marsMolaFull.path)
//		guard let ds = dss else { XCTFail(); return }
//		let band = ds.getRasterBand(1)
//		
//		let width = 5335
//		let height = 2668
//		let bytesPerPixel = MemoryLayout<Int16>.size
//		let byteCount = width * height * bytesPerPixel
//		let buf = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: MemoryLayout<Int16>.alignment)
////		defer { buf.deallocate() }
//		
//		debugLog("Started read")
//		band.rasterRead(into: buf, bufferWidth: width, bufferHeight: height,
//						xOff: 0, yOff: 0, xSize: ds.xSize, ySize: ds.ySize)
//		debugLog("Finished read")
//		
////		let cs = CGColorSpace(name: CGColorSpace.linearGray)!
//		
//		let imageData = Data(bytesNoCopy: buf, count: byteCount, deallocator: .custom({ (inP, inCount) in inP.deallocate() }))
//		let ii = CIImage(bitmapData: imageData, bytesPerRow: width * bytesPerPixel,
//							size: CGSize(width: width, height:  height),
//							format: .L16, colorSpace: nil)
//		
//		let hs = HeightShader()
//		hs.inputImage = ii
//		
//		let ctx = CIContext()
////		let ctx = CIContext(options: [.workingColorSpace : nil,
////										.outputColorSpace : nil,
////										.workingFormat : CIFormat.L16,
////										.outputPremultiplied : true,
////									])
//		let outputImage = hs.outputImage!
//		let image = ctx.createCGImage(outputImage, from: outputImage.extent)//, format: .L16, colorSpace: cs)
//		XCTAssertNotNil(image, "")
////		XCTAssertEqual(image!.bitsPerComponent, 16)
//		
//		//	Write the image to disk…
//		
//		let destURL = URL(fileURLWithPath: "/Users/rmann/Downloads/TestImage.png")
//		writeCGImageAsPNG(image!, to: destURL)
//	}
//	
//	func
//	testDirectGDALReadCVPixelBuffer()
//	{
//		GDAL.allRegister()
//		let dss = GDAL.Dataset(path: self.marsMolaFull.path)
//		guard let ds = dss else { XCTFail(); return }
//		let band = ds.getRasterBand(1)
//		
//		let width = 5335
//		let height = 2668
//		let bytesPerPixel = MemoryLayout<Int16>.size
//		let byteCount = width * height * bytesPerPixel
//		let buf = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: MemoryLayout<Int16>.alignment)
////		defer { buf.deallocate() }
//		
//		debugLog("Started read")
//		band.rasterRead(into: buf, bufferWidth: width, bufferHeight: height,
//						xOff: 0, yOff: 0, xSize: ds.xSize, ySize: ds.ySize)
//		debugLog("Finished read")
//		
////		let cs = CGColorSpace(name: CGColorSpace.linearGray)!
//		
////		let imageData = Data(bytesNoCopy: buf, count: byteCount, deallocator: .custom({ (inP, inCount) in inP.deallocate() }))
//		var pb: CVPixelBuffer?
//		let res = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, width, height, kCVPixelFormatType_OneComponent16, buf, width * bytesPerPixel,
//												{ (inMutableP, inP) in
//													inP?.deallocate()
//												}, nil, nil, &pb)
//		XCTAssertEqual(res, 0)
//		guard let pixBuf = pb else { return }
//		let ii = CIImage(cvPixelBuffer: pixBuf)
//		
//		let hs = HeightShader()
//		hs.inputImage = ii
//		
//		let ctx = CIContext()
//		let outputImage = hs.outputImage!
//		let image = ctx.createCGImage(outputImage, from: outputImage.extent)//, format: .L16, colorSpace: cs)
//		XCTAssertNotNil(image, "")
////		XCTAssertEqual(image!.bitsPerComponent, 16)
//		
//		//	Write the image to disk…
//		
//		let destURL = URL(fileURLWithPath: "/Users/rmann/Downloads/TestImage.png")
//		writeCGImageAsPNG(image!, to: destURL)
//	}
//}
//
//
//@discardableResult
//func
//writeCGImageAsPNG(_ image: CGImage, to destinationURL: URL) -> Bool
//{
//	guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
//    CGImageDestinationAddImage(destination, image, nil)
//    return CGImageDestinationFinalize(destination)
//}
