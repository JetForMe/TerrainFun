//
//	ProjectDocument.swift
//	TerrainFun
//
//	Created by Rick Mann on 2021-04-11.
//

import SwiftUI

import CoreImage
import UniformTypeIdentifiers




extension
UTType
{
	static var exampleText: UTType {
		UTType(importedAs: "com.example.plain-text")
	}
	static let project						=	UTType(exportedAs: "com.latencyzero.TerrainFun.project")
}

class
ProjectDocument : ReferenceFileDocument
{
	typealias Snapshot = [Layer]
	
	init()
	{
	}
	
	required
	init(configuration: ReadConfiguration)
		throws
	{
	}
	
	func
	snapshot(contentType: UTType)
		throws
		-> [Layer]
	{
		return self.layers
	}
	
	func
	fileWrapper(snapshot: [Layer], configuration: WriteConfiguration)
		throws
		-> FileWrapper
	{
		let data = Data()
		return .init(regularFileWithContents: data)
	}
	
	
	func
	importFile()
	{
//		let url = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/Mars_HRSC_MOLA_BlendDEM_Global_200mp_v2.tif")
//		let ip = BigTIFFImageProvider(contentsOf: url)
//		let ci = CIImage(imageProvider: ip, size: 0, 0, format: .L16, colorSpace: nil, options: [.providerTileSize : [ 128, 128 ]])
	}
	
	func
	importFile(url inURL: URL)
	{
		//	TODO: Don't assume all files are DEMs
		
		let newLayer = DEMLayer(url: inURL)
		DispatchQueue.main.async
		{
			self.layers.append(newLayer)
		}
		
		//	Generate the working image…
		//	TODO: Do this in the background. We’re actually called on a backround queue, but let's not rely on that.
		
		guard
			let ds = GDAL.Dataset(url: inURL)
		else
		{
			debugLog("Unabled to create dataset")
			return
		}
		
		let originalWidth = ds.xSize
		let originalHeight = ds.ySize
		newLayer.sourceSize = CGSize(width: CGFloat(originalWidth), height: CGFloat(originalHeight))
		
		let workingImage = image(ofMaximumSize: CGSize(width: 2048, height: 2048), from: ds)
		newLayer.workingImage = workingImage
	}
	
	func
	image(ofMaximumSize inSize: CGSize, from inSource: GDAL.Dataset)
		-> CGImage
	{
		//	TODO: So much error handling and flexibility needed here!
		
		let originalWidth = inSource.xSize
		let originalHeight = inSource.ySize
		let aspectRatio = CGFloat(originalWidth) / CGFloat(originalHeight)
		
		let width = ceil(inSize.width)
		let height = ceil(width / aspectRatio)
		let bytesPerPixel = MemoryLayout<Int16>.size
		let byteCount = Int(width) * Int(height) * bytesPerPixel
		let buf = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: MemoryLayout<Int16>.alignment)
		
		debugLog("Started read")
		let band = inSource.getRasterBand(1)
		band.rasterRead(into: buf, bufferWidth: Int(width), bufferHeight: Int(height),
						xOff: 0, yOff: 0, xSize: originalWidth, ySize: originalHeight)
		debugLog("Finished read")
		
		var pb: CVPixelBuffer?
		let result = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, Int(width), Int(height), kCVPixelFormatType_OneComponent16, buf, Int(width) * bytesPerPixel,
												{ (inMutableP, inP) in
													inP?.deallocate()
												}, nil, nil, &pb)
		assert(result == 0)
		guard let pixBuf = pb else { assert(false) }
		let ii = CIImage(cvPixelBuffer: pixBuf)
		
		let hs = HeightShader()
		hs.inputImage = ii
		
		let ctx = CIContext()
		let outputImage = hs.outputImage!
		let image = ctx.createCGImage(ii, from: outputImage.extent)!
		return image
	}
	
	func
	addTerrainGeneratorLayer()
	{
		let newLayer = TerrainGeneratorLayer()
		self.layers.append(newLayer)
	}
	
	@Published	var				layers						:	[Layer]					=	[Layer]()


	static		var				readableContentTypes		:	[UTType]				{ [.project] }
}



