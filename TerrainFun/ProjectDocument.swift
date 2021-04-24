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
	
	@Published	var				layers						:	[Layer]					=	[Layer]()


	static		var				readableContentTypes		:	[UTType]				{ [.project] }
}



