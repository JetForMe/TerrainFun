//
//  TIFFImage.swift
//  TerrainFun
//
//  Created by Rick Mann on 2020-07-29.
//  Copyright © 2020 Latency: Zero, LLC. All rights reserved.
//

import Foundation


/**
	TIFF:		https://www.adobe.io/content/dam/udp/en/open/standards/tiff/TIFF6.pdf
	BigTIFF:	http://bigtiff.org
				https://www.awaresystems.be/imaging/tiff/bigtiff.html
				http://www.simplesystems.org/libtiff//bigtiffdesign.html
	GeoTIFF:	http://geotiff.maptools.org/spec/contents.html
*/

struct
TIFFImageA
{
	enum Error : Swift.Error
	{
		case invalidTIFFFormat
		case invalidOffsetSize(Int)					//	The offset size (associated value) can't be processed by this library
		case invalidCompression
		case invalidResolutionUnit
		case invalidPredictor
		case invalidModelType
		case invalidRasterType
		case tagTypeConversionError					//	Attempted to read a tag value of incompatible type
	}
	
	enum FormatVersion : UInt16
	{
		case v42			=	42					//	Original TIFF, 32-bit offsets
		case v43			=	43					//	BigTIFF, 64-bit offsets
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
		let endian: UInt16 = self.reader.get()				//	Bytes 0-1 (endian)
		self.reader.bigEndian = endian == 0x4d4d
		let formatVersion: UInt16 = reader.get()			//	Bytes 2-3 (format version)
		if formatVersion == 42
		{
			self.formatVersion = .v42
		}
		else if formatVersion == 43
		{
			self.formatVersion = .v43
			let offsetByteSize: UInt16 = self.reader.get()	//	Bytes 4-5, offset size, currently only size==8 supported
			if offsetByteSize != 8
			{
				throw Error.invalidOffsetSize(Int(offsetByteSize))
			}
			let padding: UInt16 = self.reader.get()			//	Bytes 6-7, should be zero
			if padding != 0
			{
				throw Error.invalidTIFFFormat
			}
			
		}
		else
		{
			throw Error.invalidTIFFFormat
		}
		
		//	Get the offset to the first IFD and jump to it…
		
		let offset = readOffset()
		self.reader.seek(to: offset)
		
		//	The entry count is 16 bit for TIFF v42, 64-bit for v43 (BigTIFF)…
		
		let entryCount: UInt64 = readOffset()
		
		var ifd = IFD()
		for _ in 0..<entryCount
		{
			let de = readDirectoryEntry()
			self.directoryEntries.append(de)
			debugLog("Entry: \(de)")
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
						let saveIdx = self.reader.idx
						self.reader.seek(to: de.offset)
						
						if de.type == .short
						{
							for _ in 0..<de.count
							{
								let v: UInt16 = self.reader.get()
								ifd.stripOffsets.append(UInt64(v))
							}
						}
						else if de.type == .long
						{
							for _ in 0..<de.count
							{
								let v: UInt32 = self.reader.get()
								ifd.stripOffsets.append(UInt64(v))
							}
						}
						else
						{
							throw Error.invalidTIFFFormat
						}
						self.reader.seek(to: saveIdx)
					
					case .samplesPerPixel:
						ifd.samplesPerPixel = UInt16(try de.uint32())
					
					case .rowsPerStrip:
						ifd.rowsPerStrip = try de.uint32()
						break
					
					case .stripByteCounts:
						let saveIdx = self.reader.idx
						self.reader.seek(to: de.offset)
						ifd.stripByteCounts = self.reader.get(count: de.count)
//						if de.type == .short
//						{
//							for _ in 0..<de.count
//							{
//								let v: UInt16 = self.reader.get()
//								ifd.stripByteCounts.append(UInt32(v))
//							}
//						}
//						else if de.type == .long
//						{
//							for _ in 0..<de.count
//							{
//								let v: UInt32 = self.reader.get()
//								ifd.stripByteCounts.append(v)
//							}
//						}
//						else
//						{
//							throw Error.invalidTIFFFormat
//						}
						self.reader.seek(to: saveIdx)
					
					case .xResolution:
						let res: Rational = self.reader.get()
						debugLog("xres: \(res)")
					
					case .planarConfiguration:
						ifd.planarConfiguration = UInt16(try de.uint32())
					
					case .predictor:
						ifd.predictor = try Predictor.predictor(from: UInt32(de.offset))
						
					case .tileWidth:
						ifd.tileWidth = try de.uint32()
						
					case .tileLength:
						ifd.tileLength = try de.uint32()
					
					case .tileOffsets:
						let saveIdx = self.reader.idx
						ifd.tileOffsets = self.reader.get(count: de.count)
						self.reader.seek(to: saveIdx)
						
					case .tileByteCounts:
						let saveIdx = self.reader.idx
						if de.type == .long
						{
							ifd.tileByteCounts = self.reader.get(count: de.count)
						}
						else if de.type == .short
						{
							let vals: [UInt16] = self.reader.get(count: de.count)
							ifd.tileByteCounts = vals.map { UInt32($0) }
						}
						else
						{
							throw Error.invalidTIFFFormat
						}
						self.reader.seek(to: saveIdx)
						
					case .sampleFormat:
						ifd.sampleFormat = UInt16(try de.uint32())
					
					case .modelPixelScale:
						let saveIdx = self.reader.idx
						self.reader.seek(to: de.offset)
						
						//	Read three doubles…
						
						ifd.scaleX = self.reader.get()
						ifd.scaleY = self.reader.get()
						ifd.scaleZ = self.reader.get()
						self.reader.seek(to: saveIdx)
					
					case .modelTiePoint:
						let saveIdx = self.reader.idx
						self.reader.seek(to: de.offset)
						
						//	Read N*6 doubles (N is number of tie points)…
						
						let tiePointCount = de.count / 6
						for _ in 0..<tiePointCount
						{
							let mtp = ModelTiePoint(i: self.reader.get(),
													j: self.reader.get(),
													k: self.reader.get(),
													x: self.reader.get(),
													y: self.reader.get(),
													z: self.reader.get())
							ifd.modelTiePoints.append(mtp)
						}
						self.reader.seek(to: saveIdx)
					
					case .gdalMetadata:
						break
					
					case .gdalNoData:
						break
					
					case .geoKeyDirectory:
						assert(de.type == .short)
						assert(de.count >= 4)
						let saveIdx = self.reader.idx
						self.reader.seek(to: de.offset)
						let keyDirectoryVersion: UInt16 = self.reader.get()
						let keyRevision: UInt16 = self.reader.get()
						let minorVersion: UInt16 = self.reader.get()
						let keyCount: UInt16 = self.reader.get()
						assert(de.count == keyCount * 4 + 4)
						for _ in 0..<keyCount
						{
							let geoKey = readGeoKeyEntry()
							ifd.geoKeys.append(geoKey)
							debugLog("\(geoKey)")
						}
						self.reader.seek(to: saveIdx)
					
					case .geoDoubleParams:
						ifd.geoDoubleParams = [Double](repeating: 0.0, count: Int(de.count))
						let saveIdx = self.reader.idx
						self.reader.seek(to: de.offset)
						for idx in 0..<Int(de.count)
						{
							ifd.geoDoubleParams[idx] = self.reader.get()
						}
						self.reader.seek(to: saveIdx)
						
					
					default:
						debugLog("Skiping tag \(tag)")
						break;
				}
			}
		}
		
		//	Post-process the GeoKeys…
		
		for gk in ifd.geoKeys
		{
			switch (gk.key)
			{
				case .modelType:
					ifd.modelType = try ModelType.model(from: UInt32(gk.valueOffset))
				
				case .rasterType:
					ifd.rasterType = try RasterType.raster(from: UInt32(gk.valueOffset))
				
				default:
					debugLog("Skipping unhandled geoKey \(String(describing: gk.key))")
			}
		}
		
		//	More directories?
		
		let nextOffset: UInt32 = self.reader.get()
		if nextOffset > 0
		{
			debugLog("There are more IFDs")
		}
		
		debugLog("Num dir entries: \(self.directoryEntries.count)")
		debugLog("IFD: \(ifd)")
		self.ifd = ifd
	}
	
	/**
		TIFF format version v43 increased the size of offsets and counts
		to 64-bit. We treat all such values as 64-bit, and funnel reading
		them through this method to read the correct number of bytes,
		depending on the version.
	*/
	
	mutating
	func
	readOffset()
		-> UInt64
	{
		let offset: UInt64
		switch (self.formatVersion)
		{
			case .v42:
				let offset32: UInt32 = self.reader.get()
				offset = UInt64(offset32)
			
			case .v43:
				offset = self.reader.get()
		}
		
		return offset
	}
	
	/**
		Reads a DirectoryEntry at the current reader index. When complete, the current index
		points to the byte after the entry.
	*/
	
	mutating
	func
	readDirectoryEntry()
		-> DirectoryEntry
	{
		let tagV: UInt16 = self.reader.get()
		let tag = Tag(rawValue: tagV)
		if tag == nil
		{
			debugLog("Unknown tag \(tagV)")
		}
		let de = DirectoryEntry(tag: tag,
								type: TagType(rawValue: self.reader.get()) ?? .undefined,
								count: readOffset(),
								offset: readOffset())
		return de
	}
	
	/**
		Reads a GeoKeyEntry at the current reader index.
	*/
	
	mutating
	func
	readGeoKeyEntry()
		-> GeoKeyEntry
	{
		let gke = GeoKeyEntry(key: GeoKey(rawValue: self.reader.get()),
								tagLoc: Tag(rawValue: self.reader.get()),
								count: self.reader.get(),
								valueOffset: self.reader.get())
		return gke
	}
	
	mutating
	func
	pixelValue(x inX : Int, y inY: Int)
		-> UInt16
	{
		guard
			let ifd = self.ifd
		else
		{
			debugLog("No IFD!")
			return 0
		}
		
		//	Determine which strip the pixel is in…
		
		let strip = inY / Int(ifd.rowsPerStrip)
		let stripOffset = ifd.stripOffsets[strip]
		let yInStrip = inY % Int(ifd.rowsPerStrip)
		let idx = yInStrip * Int(ifd.width) + inX
		if ifd.bitsPerSample == 16
		{
			let saveIdx = self.reader.idx
			let offset = Int(stripOffset) + 2 * idx
			self.reader.seek(to: offset)
			let v: UInt16 = self.reader.get()
			self.reader.seek(to: saveIdx)
			return v
		}
		else
		{
			debugLog("Unhandled bits per sample")
		}
		return 0
	}
	
	/**
		IFD: Image File Directory
		
		One or more per file. Contains the parsed data from the TIFF IFD.
	*/
	
	struct
	IFD : CustomStringConvertible
	{
		var		width					:	UInt32						=	0
		var		height					:	UInt32						=	0
		var		blackIsZero												=	true
		var		compression				:	CompressionType				=	.none
		var		rowsPerStrip			:	UInt32						=	0
		var		stripByteCounts			:	[UInt64]					=	[UInt64]()
		var		stripOffsets			:	[UInt64]					=	[UInt64]()
		var		bitsPerSample			:	UInt16						=	0
		var		samplesPerPixel			:	UInt16						=	0
		var		xRes					:	Int							=	0
		var		yRes					:	Int = 0
		var		planarConfiguration		:	UInt16						=	0
		var		orientation				:	Int = 0
		var		xPos					:	Int = 0
		var		yPos					:	Int = 0
		var		resolutionUnit			:	ResolutionUnit				=	.inch
		
		var		predictor				:	Predictor					=	.none
		var		tileWidth				:	UInt32						=	0
		var		tileLength				:	UInt32						=	0
		var		tileOffsets				:	[UInt64]					=	[UInt64]()
		var		tileByteCounts			:	[UInt64]					=	[UInt64]()
		
		var		sampleFormat			:	UInt16						=	0
		var		scaleX					:	Double						=	1.0
		var		scaleY					:	Double						=	1.0
		var		scaleZ					:	Double						=	1.0
		var		modelTiePoints											=	[ModelTiePoint]()
		var		geoKeys													=	[GeoKeyEntry]()
		var		geoDoubleParams											=	[Double]()
		var		modelType				:	ModelType?
		var		rasterType				:	RasterType?
		
		
		var description: String
		{
			return "IFD(width: \(self.width), height: \(self.height), resUnit: \(self.resolutionUnit), xRes: \(self.xRes), yRes: \(self.yRes))"
		}
	}
	
	struct
	Rational : CustomDebugStringConvertible
	{
		let		numerator		:	UInt32
		let		denominator		:	UInt32
		
		var debugDescription: String
		{
			return "\(self.numerator) / \(self.denominator) = \(Double(self.numerator) / Double(self.denominator)))"
		}
	}
	
	struct
	ModelTiePoint
	{
		let i		:	Double
		let j		:	Double
		let k		:	Double
		let x		:	Double
		let y		:	Double
		let z		:	Double
	}
	
	struct
	DirectoryEntry
	{
		let		tag			:	Tag?
		let		type		:	TagType
		let		count		:	UInt64
		let		offset		:	UInt64
		
		func
		uint32()
			throws
			-> UInt32
		{
			if self.type == .byte || self.type == .short || self.type == .long
			{
				return UInt32(self.offset)
			}
			
			throw Error.tagTypeConversionError
		}
		
		func
		uint64()
			throws
			-> UInt32
		{
			if self.type == .byte || self.type == .short || self.type == .long || self.type.long8
			{
				return self.offset
			}
			
			throw Error.tagTypeConversionError
		}
	}
	
	struct
	GeoKeyEntry
	{
		let		key			:	GeoKey?
		let		tagLoc		:	Tag?
		let		count		:	UInt16
		let		valueOffset	:	UInt16
	}
	
	enum
	GeoKey : UInt16
	{
		case modelType			=	1024
		case rasterType			=	1025
		case citation			=	1026
		
		case geographicType		=	2048
		case geoCitation		=	2049
		case geoDatum			=	2050
		case linearUnits		=	2042
		case linearUnitSize		=	2053		//	meters
		case angularUnits		=	2054		//	radians
		case semiMajorAxis		=	2057		//	GeogLinearUnits
		case semiMinorAxis		=	2058		//	GeogLinearUnits
		case inverseFlatteing	=	2059		//	Rational
		case toWGS84			=	2062		//	https://trac.osgeo.org/geotiff/wiki/TOWGS84GeoKey
	}
	
	enum
	ModelType
	{
		case projected
		case geographic
		case geocentric
		
		static
		func
		model(from inVal: UInt32)
			throws
			-> ModelType
		{
			switch (inVal)
			{
				case 1:		return .projected
				case 2:		return .geographic
				case 3:		return .geocentric
				default:
					throw Error.invalidModelType
			}
		}
	}
	
	enum
	RasterType
	{
		case pixelIsArea
		case pixelIsPoint
		
		static
		func
		raster(from inVal: UInt32)
			throws
			-> RasterType
		{
			switch (inVal)
			{
				case 1:		return .pixelIsArea
				case 2:		return .pixelIsPoint
				default:
					throw Error.invalidRasterType
			}
		}
	}
	
	enum
	CompressionType
	{
		case none
		case ccitt
		case t4
		case t6
		case lzw
		case jpegOld
		case jpegNew
		case deflate
		case pkzipDeflate
		case packBits
		
		static
		func
		compression(fromVal inVal: UInt64)
			throws
			-> CompressionType
		{
			switch (inVal)
			{
				case 1:		return .none
				case 2:		return .ccitt
				case 3:		return .t4
				case 4:		return .t6
				case 5:		return .lzw
				case 6:		return .jpegOld
				case 7:		return .jpegNew
				case 8:		return .deflate
				case 32946:	return .pkzipDeflate
				case 32772:	return .packBits
				default:
					throw Error.invalidCompression
			}
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
		case xResolution						=	282				//	Rational
		case yResolution						=	283				//	Rational
		case planarConfiguration				=	284
		case xPosition							=	286
		case yPosition							=	287
		case resolutionUnit						=	296
		
		case predictor							=	317
		case tileWidth							=	322
		case tileLength							=	323
		case tileOffsets						=	324
		case tileByteCounts						=	325
		
		case sampleFormat						=	339
		
		case modelPixelScale					=	33550			//	double
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
		case ifd			=	13
		
		case long8			=	16		//	BigTIFF Types
		case slong8			=	17
		case ifd8			=	18
	}
	
	enum ResolutionUnit
	{
		case none
		case inch				//	Default
		case centimeter
		
		static
		func
		resolution(fromVal inVal: UInt32)
			throws
			-> ResolutionUnit
		{
			switch (inVal)
			{
				case 1:		return .none
				case 2:		return .inch
				case 3:		return .centimeter
				default:
					throw Error.invalidResolutionUnit
			}
		}
	}
	
	enum
	Predictor
	{
		case none
		case horizontal
		case floatingPointHorizontal
		
		static
		func
		predictor(from inVal: UInt32)
			throws
			-> Predictor
		{
			switch (inVal)
			{
				case 1:		return .none
				case 2:		return .horizontal
				case 3:		return .floatingPointHorizontal
				default:
					throw Error.invalidPredictor
			}
		}
	}
	
	var			formatVersion		:	FormatVersion	=	.v42
	var			reader				:	BinaryReader
	var			directoryEntries						=	[DirectoryEntry]()
	var			ifd					:	IFD?
}



extension
BinaryReader
{
	@inlinable
	mutating
	func
	get()
		-> TIFFImageA.Rational
	{
		let n: UInt32 = get()
		let d: UInt32 = get()
		return TIFFImageA.Rational(numerator: n, denominator: d)
	}
	
	/**
		Read count UInt16s at the current offset.
	*/
	
	@inlinable
	mutating
	func
	get(count inCount: UInt64)
		-> [UInt16]
	{
		precondition(inCount < Int.max)		//	Throw exception?
		
		var result = [UInt16](repeating: 0, count: Int(inCount))
		for idx in 0..<Int(inCount)
		{
			result[idx] = get()
		}
		
		return result
	}
	
	/**
		Read count UInt32s at the current offset.
	*/
	
	@inlinable
	mutating
	func
	get(count inCount: UInt64)
		-> [UInt32]
	{
		precondition(inCount < Int.max)		//	Throw exception?
		
		var result = [UInt32](repeating: 0, count: Int(inCount))
		for idx in 0..<Int(inCount)
		{
			result[idx] = get()
		}
		
		return result
	}
	
	/**
		Read count UInt64s at the current offset.
	*/
	
	@inlinable
	mutating
	func
	get(count inCount: UInt64)
		-> [UInt64]
	{
		precondition(inCount < Int.max)		//	Throw exception?
		
		var result = [UInt64](repeating: 0, count: Int(inCount))
		for idx in 0..<Int(inCount)
		{
			result[idx] = get()
		}
		
		return result
	}
	
	
}
