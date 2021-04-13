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

struct
ProjectDocument : FileDocument
{
	var text: String

	init(text: String = "Hello, world!") {
		self.text = text
	}

	static var readableContentTypes: [UTType] { [.project] }

	init(configuration: ReadConfiguration) throws {
		guard let data = configuration.file.regularFileContents,
			  let string = String(data: data, encoding: .utf8)
		else {
			throw CocoaError(.fileReadCorruptFile)
		}
		text = string
	}
	
	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let data = text.data(using: .utf8)!
		return .init(regularFileWithContents: data)
	}
	
	func
	importFile()
	{
//		let url = URL(fileURLWithPath: "/Users/rmann/Projects/Personal/TerrainFun/SampleData/Mars_HRSC_MOLA_BlendDEM_Global_200mp_v2.tif")
//		let ip = BigTIFFImageProvider(contentsOf: url)
//		let ci = CIImage(imageProvider: ip, size: 0, 0, format: .L16, colorSpace: nil, options: [.providerTileSize : [ 128, 128 ]])
	}
}



