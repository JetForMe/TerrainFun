//
//	TerrainFunApp.swift
//	TerrainFun
//
//	Created by Rick Mann on 2021-04-11.
//

import SwiftUI

import Combine



@main
struct
TerrainFunApp: App
{
	init()
	{
		GDAL.allRegister()
	}
	
	var
	body: some Scene
	{
		DocumentGroup(newDocument: ProjectDocument.init)
		{ inGroup in
			ProjectWindowContentView(document: inGroup.document)
				.frame(minWidth: 301.0, minHeight: 100.0)
				.onReceive(self.addTerrainGeneratorLayerCommand) { _ in
					inGroup.document.addTerrainGeneratorLayer()
				}
		}
		.commands
		{
			CommandMenu("Layers")
			{
				Button("Add Terrain Generator Layer")
				{
					self.addTerrainGeneratorLayerCommand.send()
				}
			}
			CommandMenu("Tests")
			{
				Button("Test CIImageProvider")
				{
					testCIImageProvider()
				}
			}
		}
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
		assert(image != nil, "")
		
		//	Write the image to disk…
		
		let destURL = URL(fileURLWithPath: "/Users/rmann/Downloads/TestImage.png")
		writeCGImage(image!, to: destURL)
	}
	
	
	private	let			addTerrainGeneratorLayerCommand			=	PassthroughSubject<Void, Never>()
}

@discardableResult func writeCGImage(_ image: CGImage, to destinationURL: URL) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypePNG, 1, nil) else { return false }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}
