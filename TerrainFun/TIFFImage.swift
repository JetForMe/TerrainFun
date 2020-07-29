//
//  TIFFImage.swift
//  TerrainFun
//
//  Created by Rick Mann on 2020-07-29.
//  Copyright © 2020 Latency: Zero, LLC. All rights reserved.
//

import Foundation


/**
	TIFF: https://www.adobe.io/content/dam/udp/en/open/standards/tiff/TIFF6.pdf
	GeoTIFF: http://geotiff.maptools.org/spec/contents.html
*/

struct
TIFFImage
{
	enum Error : Swift.Error
	{
		case invalidTIFFFormat
		case invalidCompression
		case tagTypeConversionError					//	Attempted to read a tag value of incompatible type
	}
	
	init(contentsOfURL inURL: URL)
		throws
	{
		let data = try Data(contentsOf: inURL, options: .alwaysMapped)
		self.reader = BinaryReader(data: data)
		try readHeader()
	}
	
	mutating
	func
	readHeader()
		throws
	{
		let endian: UInt16 = self.reader.get()
		self.reader.bigEndian = endian == 0x4d4d
		let fortyTwo: UInt16 = reader.get()
		if fortyTwo != 42
		{
			throw Error.invalidTIFFFormat
		}
		
		let offset: UInt32 = self.reader.get()
		self.reader.seek(to: offset)
		let entryCount: UInt16 = self.reader.get()
		var ifd = IFD()
		for _ in 0..<entryCount
		{
			let de = readDirectoryEntry()
			self.directoryEntries.append(de)
			
			if let tag = de.tag
			{
				switch (tag)
				{
					case .imageWidth:
						ifd.width = try de.uint32()
					
					case .imageLength:
						ifd.height = try de.uint32()
					
					case .bitsPerSample:
						ifd.bitsPerSample = UInt16(try de.uint32())
						
					case .compression:
						ifd.compression = try CompressionType.compression(fromVal: de.offset)
					
					case .photometricInterpretation:
						ifd.blackIsZero = de.offset != 0
						
					case .stripOffsets:
						break
					
					case .samplesPerPixel:
						ifd.samplesPerPixel = UInt16(try de.uint32())
					
					case .rowsPerStrip:
						ifd.rowsPerStrip = try de.uint32()
						break
					
					case .stripByteCounts:
						break
					
					case .planarConfiguration:
						ifd.planarConfiguration = UInt16(try de.uint32())
					
					case .sampleFormat:
						ifd.sampleFormat = UInt16(try de.uint32())
					
					case .modelPixelScale:
						break
					
					case .modelTiePoint:
						break
					
					case .geoDoubleParams:
						break
					
					case .geoAsciiParams:
						break
					
					case .gdalMetadata:
						break
					
					case .gdalNoData:
						break
					
					case .geoKeyDirectory:
						break
				}
			}
		}
		
		
		
		
		let nextOffset: UInt32 = self.reader.get()
		if nextOffset > 0
		{
			debugLog("There are more IFDs")
		}
		
		debugLog("Num dirs: \(self.directoryEntries.count)")
		debugLog("IFD: \(ifd)")
	}
	
	mutating
	func
	readDirectoryEntry()
		-> DirectoryEntry
	{
		let de = DirectoryEntry(tag: Tag(rawValue: self.reader.get()),
						type: TagType(rawValue: self.reader.get()) ?? .undefined,
						count: self.reader.get(),
						offset: self.reader.get())
		return de
	}
	
	struct
	IFD
	{
		var		width				:	UInt32						=	0
		var		height				:	UInt32						=	0
		var		blackIsZero											=	true
		var		compression			:	CompressionType				=	.none
		var		rowsPerStrip		:	UInt32						=	0
		var		bitsPerSample		:	UInt16						=	0
		var		samplesPerPixel		:	UInt16						=	0
		var		planarConfiguration	:	UInt16						=	0
		var		sampleFormat		:	UInt16						=	0
	}
	
	struct
	DirectoryEntry
	{
		let		tag			:	Tag?
		let		type		:	TagType
		let		count		:	UInt32
		let		offset		:	UInt32
		
		func
		uint32()
			throws
			-> UInt32
		{
			if self.type == .byte || self.type == .short || self.type == .long
			{
				return self.offset
			}
			
			throw Error.tagTypeConversionError
		}
	}
	
	enum
	CompressionType
	{
		case none
		case ccitt
		case packBits
		
		static
		func
		compression(fromVal inVal: UInt32)
			throws
			-> CompressionType
		{
			if inVal == 0
			{
				return .none
			}
			else if inVal == 1
			{
				return .ccitt
			}
			else if inVal == 32772
			{
				return .packBits
			}
			
			throw Error.invalidCompression
		}
	}
	
	enum
	Tag : UInt16
	{
		case imageWidth							=	256
		case imageLength						=	257
		case bitsPerSample						=	258
		case compression						=	259
		case photometricInterpretation			=	262
		case stripOffsets						=	273
		case samplesPerPixel					=	277
		case rowsPerStrip						=	278
		case stripByteCounts					=	279
		case planarConfiguration				=	284
		case sampleFormat						=	339
		
		case modelPixelScale					=	33550
		case modelTiePoint						=	33922
		case geoKeyDirectory					=	34735
		case geoDoubleParams					=	34736
		case geoAsciiParams						=	34737
		
		case gdalMetadata						=	42112			//	ascii	https://www.awaresystems.be/imaging/tiff/tifftags/gdal_metadata.html
		case gdalNoData							=	42113			//	ascii	https://www.awaresystems.be/imaging/tiff/tifftags/gdal_nodata.html
	}
	
	enum TagType : UInt16
	{
		case byte			=	1
		case ascii			=	2
		case short			=	3
		case long			=	4
		case rational		=	5
		
		case sbyte			=	6
		case undefined		=	7
		case sshort			=	8
		case slong			=	9
		case srational		=	10
		case float			=	11
		case double			=	12
	}
	
	var			reader		:	BinaryReader
	var			directoryEntries			=	[DirectoryEntry]()
}
