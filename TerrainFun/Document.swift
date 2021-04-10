//
//  Document.swift
//  TerrainFun
//
//  Created by Rick Mann on 2020-07-22.
//  Copyright © 2020 Latency: Zero, LLC. All rights reserved.
//

import Cocoa

import SceneKit

import TIFFLib


class
Document: NSDocument
{

	override
	init()
	{
	    super.init()
	}

	override
	class
	var
	autosavesInPlace: Bool
	{
		return true
	}
	
	func
	makeEmptyDocument()
	{
		
	}

	override
	func
	makeWindowControllers()
	{
		// Returns the Storyboard that contains your Document window.
		let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
		let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
		self.addWindowController(windowController)
		
	}

	override func data(ofType typeName: String) throws -> Data {
		// Insert code here to write your document to data of the specified type, throwing an error in case of failure.
		// Alternatively, you could remove this method and override fileWrapper(ofType:), write(to:ofType:), or write(to:ofType:for:originalContentsURL:) instead.
		throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
	}

	override func read(from data: Data, ofType typeName: String) throws {
		// Insert code here to read your document from the given data of the specified type, throwing an error in case of failure.
		// Alternatively, you could remove this method and override read(from:ofType:) instead.
		// If you do, you should also override isEntireFileLoaded to return false if the contents are lazily loaded.
		throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
	}

	@IBAction
	func
	addTerrainImage(_ inSender: Any)
	{
		let op = NSOpenPanel()
		op.canChooseFiles = true
		op.canChooseDirectories = false
		op.allowsMultipleSelection = true
		op.beginSheetModal(for: self.windowForSheet!)
		{ (inResponse) in
			if inResponse == .OK
			{
				DispatchQueue.main.async
				{
					for url in op.urls
					{
						self.addTerrainImage(url: url)
					}
				}
			}
		}
	}
	
	func
	addTerrainImage(url inURL: URL)
	{
		guard
			let imageSource = CGImageSourceCreateWithURL(inURL as CFURL, nil),
			let imageMD = CGImageSourceCopyProperties(imageSource, nil),
			let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString:Any],
			let img = NSImage(contentsOf: inURL)
		else
		{
			debugLog("Couldn't open image at \(inURL.path)")
			return
		}
		
		let imgWidth = img.size.width
		let imgHeight = img.size.height
		debugLog("Dimensions: \(imgWidth), \(imgHeight)")
		debugLog("Num images: \(CGImageSourceGetCount(imageSource))")
		debugLog("metadata: \(imageMD)")
		if let exif = metadata[kCGImagePropertyExifDictionary]
		{
			debugLog("EXIF: \(exif)")
		}
		if let tiff = metadata[kCGImagePropertyTIFFDictionary]
		{
			debugLog("TIFF: \(tiff)")
		}
		
		//	Create a triangle mesh from the image data…
		
		let meshWidth: CGFloat = 10.0
		let meshHeight: CGFloat = 10.0
		
		//	Start by making vertices for each pixel in the image, starting
		//	in the lower-left
		
		var imgRect = CGRect(x: 0.0, y: 0.0, width: imgWidth, height: imgHeight)
		guard
			let cgImage = img.cgImage(forProposedRect: &imgRect, context: nil, hints: nil)
		else
		{
			debugLog("Couldn't get cgimage")
			return
		}
		
		let data = try! Data(contentsOf: inURL)
		let tiffImage: TIFFLib.TIFFImage = TIFFReader.readTiff(from: data)
		let directories: [TIFFFileDirectory] = tiffImage.fileDirectories()
		let directory: TIFFFileDirectory = directories[0]
		let des = directory.entries()!
//		for idx in 0..<des.count
//		{
//			let de = des[idx] as! TIFFFileDirectoryEntry
//			debugLog("de: \(de.fieldType())")
//		}
		
//		let rasters: TIFFRasters = directory.readRasters()			//	Expensive
			
		let ti = try! TIFFImageA(contentsOfURL: inURL)
		
//		let imgData = CGImageGetdata
		let xSpan = meshWidth / imgWidth
		let ySpan = meshHeight / imgHeight
		
		var vertices = [SCNVector3]()
		for y in stride(from: 0.0, to: imgHeight, by: 1.0)
		{
			let imgY = imgHeight - y
			for x in stride(from: 0.0, to: imgWidth, by: 1.0)
			{
				let v = SCNVector3(x * xSpan, 0.0, y * ySpan)
				vertices.append(v)
			}
		}
		let vertexSource = SCNGeometrySource(vertices: vertices)
		
	}

}

