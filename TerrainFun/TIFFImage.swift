//
//	TIFFImage.swift
//	TerrainFun
//
//	Created by Rick Mann on 2020-07-29.
//	Copyright © 2020 Latency: Zero, LLC. All rights reserved.
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
			self.offsetSize = Int(offsetByteSize)
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
			if case .unknown = de.tag
			{
				debugLog("Unknown tag \(de.tag)")
			}
			else
			{
				self.directoryEntries[de.tag] = de
			}
			debugLog("Processing \(de)")
			switch (de.tag)
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
					try self.reader.at(offset: de.offset)
					{
						ifd.stripOffsets = try read(count: de.count, ofType: de.type)
					}
				
				case .samplesPerPixel:
					ifd.samplesPerPixel = UInt16(try de.uint32())
				
				case .rowsPerStrip:
					ifd.rowsPerStrip = try de.uint32()
					break
				
				case .stripByteCounts:
					try self.reader.at(offset: de.offset)
					{
						ifd.stripByteCounts = try read(count: de.count, ofType: de.type)
					}
				
				case .xResolution:
					let res: Rational = self.reader.get()
					debugLog("xres: \(res)")
				
				case .planarConfiguration:
					ifd.planarConfiguration = UInt16(try de.uint32())
				
				case .predictor:
					ifd.predictor = try Predictor.from(rawValue: UInt32(de.offset))
					
				case .tileWidth:
					ifd.tileWidth = try de.uint32()
					
				case .tileLength:
					ifd.tileLength = try de.uint32()
				
				case .tileOffsets:
					try self.reader.at(offset: de.offset)
					{
						ifd.tileOffsets = try read(count: de.count, ofType: de.type)
					}
					
				case .tileByteCounts:
					try self.reader.at(offset: de.offset)
					{
						ifd.tileByteCounts = try read(count: de.count, ofType: de.type)
					}
					
				case .sampleFormat:
					ifd.sampleFormat = UInt16(try de.uint32())
				
				case .modelPixelScale:
					try self.reader.at(offset: de.offset)
					{
						//	Read three doubles…
						
						ifd.scaleX = self.reader.get()
						ifd.scaleY = self.reader.get()
						ifd.scaleZ = self.reader.get()
					}
				
				case .modelTiePoint:
					try self.reader.at(offset: de.offset)
					{
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
							debugLog("Model Tie Point: \(mtp)")
						}
					}
				
				case .gdalMetadata:
					break
				
				case .gdalNoData:
					let s = try readString(entry: de)
					let v = Int(s)
					ifd.gdalNoData = v
				
				case .geoKeyDirectory:
					//	This tag is an array of SHORTs, primarily grouped into blocks of four,
					//	with the first four being the header.
					
					assert(de.type == .short)
					assert(de.count >= 4)
					
					try self.reader.at(offset: de.offset)
					{
						//	Read the header information…
						
						let keyDirectoryVersion: UInt16 = self.reader.get()
						if keyDirectoryVersion != 1
						{
							//	TODO: Better to throw an exception here?
							debugLog("Unknown key directory version (\(keyDirectoryVersion)).")
							return
						}
						
						let keyRevision: UInt16 = self.reader.get()
						let minorVersion: UInt16 = self.reader.get()
						debugLog("Key revision: \(keyRevision).\(minorVersion)")
						
						let keyCount: UInt16 = self.reader.get()
						
						//	We should not have more keys than the count of the directory
						//	entry would allow…
						
						assert(de.count >= keyCount * 4 + 4, "de.count (\(de.count)) < \(keyCount * 4 + 4)")
						//	TODO: Handle the excess data in this Entry.
						
						//	Read each key…
						
						for _ in 0..<keyCount
						{
							let geoKey = readGeoKeyEntry()
							ifd.geoKeyEntries.append(geoKey)
							debugLog("\(geoKey)")
						}
					}
				
				case .geoDoubleParams:
					try self.reader.at(offset: de.offset)
					{
						ifd.geoDoubleParams = self.reader.get(count: de.count)
					}
					
				case .geoAsciiParams:
					let v = try readString(entry: de)
					ifd.geoStrings = v.split(separator: "|").map { String($0) }
					
				default:
					debugLog("Skipping tag \(de.tag)")
					break;
			}
		}
		
		//	Post-process the geoKeyEntries…
		
		try processGeoKeyEntries(ifd: &ifd)
		
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
	
	mutating
	func
	read(count inCount: UInt64, ofType inType: TagType)
		throws
		-> [UInt64]
	{
		if inType == .short
		{
			let v: [UInt16] = self.reader.get(count: inCount)
			return v.map { UInt64($0) }
		}
		else if inType == .long
		{
			let v: [UInt32] = self.reader.get(count: inCount)
			return v.map { UInt64($0) }
		}
		else if inType == .long8
		{
			let v: [UInt64] = self.reader.get(count: inCount)
			return v
		}
		else
		{
			throw Error.invalidTIFFFormat
		}
	}
	
	mutating
	func
	readString(entry inDE: DirectoryEntry)
		throws
		-> String
	{
		//	A string must contain a trailing null, and we’re going to ignore that,
		//	so a non-empty string must be at least two bytes…
		//	TODO: Does TIFF allow empty strings?
		
		if inDE.count < 2
		{
			throw Error.invalidTIFFFormat
		}
		
		if inDE.count < self.offsetSize			//	The string fits in the value TODO: -1?
		{
			let s: String = try self.reader.at(offset: inDE.location + 4 + UInt64(self.offsetSize))
			{
				if let s: String = self.reader.get(count: inDE.count - 1)		//	Exclude trailing NULL
				{
					debugLog("String \(s)")
					return s
				}
				throw Error.invalidTIFFFormat
			}
			return s
		}
		else
		{
			let s: String = try self.reader.at(offset: inDE.offset)
			{
				if let s: String = self.reader.get(count: inDE.count - 1)		//	Exclude trailing NULL
				{
					debugLog("String '\(s)'")
					return s
				}
				throw Error.invalidTIFFFormat
			}
			return s
		}
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
		let loc = self.reader.idx
		let tagV: UInt16 = self.reader.get()
		let tag = Tag.from(rawValue: tagV)
		let de = DirectoryEntry(location: UInt64(loc),
								tag: tag,
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
		let kv: UInt16 = self.reader.get()
		let geoKey = GeoKey.from(rawValue: kv)
		let gke = GeoKeyEntry(key: geoKey,
								tagLoc: Tag.from(rawValue: self.reader.get()),
								count: self.reader.get(),
								valueOffset: self.reader.get())
		return gke
	}
	
	mutating
	func
	processGeoKeyEntries(ifd inIFD: inout IFD)
		throws
	{
		for gk in inIFD.geoKeyEntries
		{
			switch (gk.key)
			{
				case .modelType:
					inIFD.modelType = try ModelType.model(from: UInt32(gk.valueOffset))
				
				case .rasterType:
					inIFD.rasterType = try RasterType.raster(from: UInt32(gk.valueOffset))
				
				case .angularUnits:
					inIFD.angularUnits = try AngularUnit.from(rawValue: UInt16(gk.valueOffset))
				
				case .geoDatum:
					inIFD.datum = GeodeticDatum(rawValue: UInt16(gk.valueOffset)) ?? .undefined
				
				case .geogEllipsoid:
					inIFD.ellipsoid = GeogEllipsoid(rawValue: UInt16(gk.valueOffset)) ?? .undefined
				
				case .semiMajorAxis:
					inIFD.semiMajorAxis = inIFD.geoDoubleParams[Int(gk.valueOffset)]
					
				case .semiMinorAxis:
					inIFD.semiMinorAxis = inIFD.geoDoubleParams[Int(gk.valueOffset)]
				
				case .geogPrimeMeridianLong:
					inIFD.primeMeridianLongitude = inIFD.geoDoubleParams[Int(gk.valueOffset)]
					
				case .toWGS84:
					inIFD.toWGS84 = [Double](repeating: 0.0, count: Int(gk.count))
					for idx in 0 ..< gk.count
					{
						let d = inIFD.geoDoubleParams[Int(gk.valueOffset + idx)]
						inIFD.toWGS84[Int(idx)] = d
					}
				
				default:
					debugLog("Skipping unhandled geoKey \(String(describing: gk.key))")
			}
		}
	}
	
	mutating
	func
	pixelValue(x inX : Int, y inY: Int)
		throws
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
			let offset = Int(stripOffset) + 2 * idx
			let v: UInt16 = try self.reader.at(offset: UInt64(offset))
			{
				let v: UInt16 = self.reader.get()
				return v
			}
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
		var		stripShortData			:	[[UInt16]?]?
		
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
		var		geoKeyEntries											=	[GeoKeyEntry]()
		var		geoDoubleParams											=	[Double]()
		var		geoStrings												=	[String]()
		
		var		modelType				:	ModelType?
		var		rasterType				:	RasterType?
		var		angularUnits			:	AngularUnit					=	.degree
		var		datum					:	GeodeticDatum				=	.undefined
		var		ellipsoid				:	GeogEllipsoid				=	.undefined
		var		semiMajorAxis			:	Double						=	0.0
		var		semiMinorAxis			:	Double						=	0.0
		var		invFlattening			:	Double						=	Double.infinity
		var		azimuthUnits			:	AngularUnit					=	.degree
		var		primeMeridianLongitude	:	Double						=	0.0
		var		toWGS84					:	[Double]					=	[Double]()		//	https://trac.osgeo.org/geotiff/wiki/TOWGS84GeoKey
		
		var		gdalNoData				:	Int?
		
		var description: String
		{
			return """
			IFD(width: \(self.width), height: \(self.height), resUnit: \(self.resolutionUnit), xRes: \(self.xRes), yRes: \(self.yRes), \
			strips: \(self.stripOffsets.count), rowsPerStrip: \(self.rowsPerStrip))
			"""
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
		let		location	:	UInt64			//	Location in file of this Entry
		let		tag			:	Tag
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
			-> UInt64
		{
			if self.type == .byte || self.type == .short || self.type == .long || self.type == .long8
			{
				return self.offset
			}
			
			throw Error.tagTypeConversionError
		}
	}
	
	struct
	GeoKeyEntry
	{
		let		key			:	GeoKey
		let		tagLoc		:	Tag
		let		count		:	UInt16
		let		valueOffset :	UInt16
	}
	
	enum
	GeoKey
	{
		case unknown(UInt16)
		
		case modelType
		case rasterType
		case citation
		
		case geographicType
		case geoCitation
		case geoDatum
		case linearUnits
		case linearUnitSize						//	meters
		case angularUnits						//	radians
		case angularUnitSize					//	radians
		case geogEllipsoid						//	Section 6.3.2.3 code
		case semiMajorAxis						//	GeogLinearUnits
		case semiMinorAxis						//	GeogLinearUnits
		case inverseFlatteing					//	Rational
		case azimuthUnits						//	Section 6.3.1.4 code
		case geogPrimeMeridianLong				//	GeogAngularUnits
		case toWGS84							//	https://trac.osgeo.org/geotiff/wiki/TOWGS84GeoKey
		
//		case modelType			=	1024
//		case rasterType			=	1025
//		case citation			=	1026
//
//		case geographicType		=	2048
//		case geoCitation		=	2049
//		case geoDatum			=	2050
//		case linearUnits		=	2042
//		case linearUnitSize		=	2053		//	meters
//		case angularUnits		=	2054		//	radians
//		case semiMajorAxis		=	2057		//	GeogLinearUnits
//		case semiMinorAxis		=	2058		//	GeogLinearUnits
//		case inverseFlatteing	=	2059		//	Rational
//		case toWGS84			=	2062		//	https://trac.osgeo.org/geotiff/wiki/TOWGS84GeoKey
		
		static
		func
		from(rawValue inRaw: UInt16)
			-> GeoKey
		{
			return self.rawValueMapping[inRaw] ?? .unknown(inRaw)
		}
		
		static let rawValueMapping: [ UInt16 : GeoKey ] =
		[
			1024 : .modelType,
			1025 : .rasterType,
			1026 : .citation,

			2048 : .geographicType,
			2049 : .geoCitation,
			2050 : .geoDatum,
			2042 : .linearUnits,
			2053 : .linearUnitSize,
			2054 : .angularUnits,
			2055 : .angularUnitSize,
			2056 : .geogEllipsoid,
			2057 : .semiMajorAxis,
			2058 : .semiMinorAxis,
			2059 : .inverseFlatteing,
			2060 : .azimuthUnits,
			2061 : .geogPrimeMeridianLong,
			2062 : .toWGS84,
		]
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
				case 32946: return .pkzipDeflate
				case 32772: return .packBits
				default:
					throw Error.invalidCompression
			}
		}
	}
	
	enum
	Tag : Hashable
	{
		case unknown(UInt16)
		case imageWidth
		case imageLength
		case bitsPerSample
		case compression
		case photometricInterpretation
		case stripOffsets
		case samplesPerPixel
		case rowsPerStrip
		case stripByteCounts
		case xResolution											//	Rational
		case yResolution											//	Rational
		case planarConfiguration
		case xPosition
		case yPosition
		case resolutionUnit
		
		case predictor
		case tileWidth
		case tileLength
		case tileOffsets
		case tileByteCounts
		
		case sampleFormat
		
		case modelPixelScale										//	double
		case modelTiePoint
		case geoKeyDirectory
		case geoDoubleParams
		case geoAsciiParams
		
		case gdalMetadata											//	ascii	https://www.awaresystems.be/imaging/tiff/tifftags/gdal_metadata.html
		case gdalNoData												//	ascii	https://www.awaresystems.be/imaging/tiff/tifftags/gdal_nodata.html
		
//		case imageWidth							=	256
//		case imageLength						=	257
//		case bitsPerSample						=	258
//		case compression						=	259
//		case photometricInterpretation			=	262
//		case stripOffsets						=	273
//		case samplesPerPixel					=	277
//		case rowsPerStrip						=	278
//		case stripByteCounts					=	279
//		case xResolution						=	282				//	Rational
//		case yResolution						=	283				//	Rational
//		case planarConfiguration				=	284
//		case xPosition							=	286
//		case yPosition							=	287
//		case resolutionUnit						=	296
//
//		case predictor							=	317
//		case tileWidth							=	322
//		case tileLength							=	323
//		case tileOffsets						=	324
//		case tileByteCounts						=	325
//
//		case sampleFormat						=	339
//
//		case modelPixelScale					=	33550			//	double
//		case modelTiePoint						=	33922
//		case geoKeyDirectory					=	34735
//		case geoDoubleParams					=	34736
//		case geoAsciiParams						=	34737
//
//		case gdalMetadata						=	42112			//	ascii	https://www.awaresystems.be/imaging/tiff/tifftags/gdal_metadata.html
//		case gdalNoData							=	42113			//	ascii	https://www.awaresystems.be/imaging/tiff/tifftags/gdal_nodata.html
		
		static
		func
		from(rawValue inRaw: UInt16)
			-> Tag
		{
			return self.rawValueMapping[inRaw] ?? .unknown(inRaw)
		}
		
		static let rawValueMapping: [ UInt16 : Tag ] =
		[
			256 : .imageWidth,
			257 : .imageLength,
			258 : .bitsPerSample,
			259 : .compression,
			262 : .photometricInterpretation,
			273 : .stripOffsets,
			277 : .samplesPerPixel,
			278 : .rowsPerStrip,
			279 : .stripByteCounts,
			282 : .xResolution,
			283 : .yResolution,
			284 : .planarConfiguration,
			286 : .xPosition,
			287 : .yPosition,
			296 : .resolutionUnit,

			317 : .predictor,
			322 : .tileWidth,
			323 : .tileLength,
			324 : .tileOffsets,
			325 : .tileByteCounts,

			339 : .sampleFormat,

			33550 : .modelPixelScale,
			33922 : .modelTiePoint,
			34735 : .geoKeyDirectory,
			34736 : .geoDoubleParams,
			34737 : .geoAsciiParams,

			42112 : .gdalMetadata,
			42113 : .gdalNoData,
		]
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
		from(rawValue inVal: UInt32)
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
	
	enum
	AngularUnit
	{
		case radian
		case degree
		case arcMinute
		case arcSecond
		case gradian
		case gon
		case dms
		case dmsHemisphere
		
		static
		func
		from(rawValue inValue: UInt16)
			throws
			-> AngularUnit
		{
			guard let v = self.rawValueMapping[inValue] else
			{
				throw Error.invalidTIFFFormat
			}
			
			return v
		}
		
		static let rawValueMapping: [ UInt16 : AngularUnit ] =
		[
			9101 : .radian,
			9102 : .degree,
			9103 : .arcMinute,
			9104 : .arcSecond,
			9105 : .gradian,
			9106 : .gon,
			9107 : .dms,
			9108 : .dmsHemisphere,
		]
	}
	
	enum
	GeodeticDatum : UInt16
	{
		case undefined				=	0
		case userDefined			=	32767
	}
	
	enum
	GeogEllipsoid : UInt16
	{
		case undefined				=	0
		case userDefined			=	32767
	}
	
	var			formatVersion		:	FormatVersion	=	.v42
	var			offsetSize			:	Int				=	4			//	Size of offsets in bytes. 8 for BigTIFF/.v43
	var			reader				:	BinaryReader
	var			directoryEntries						=	[Tag:DirectoryEntry]()
	var			ifd					:	IFD?
}



extension
BinaryReader
{
	@inlinable
	//mutating
	func
	get()
		-> TIFFImageA.Rational
	{
		let n: UInt32 = get()
		let d: UInt32 = get()
		return TIFFImageA.Rational(numerator: n, denominator: d)
	}
}

extension
TIFFImageA.ModelTiePoint : CustomDebugStringConvertible
{
	var
	debugDescription: String
	{
		return "I: \(self.i), J: \(self.j), K: \(self.k) -> X: \(self.x), Y: \(self.y), Z: \(self.z)"
	}
}

class
BigTIFFImageProvider : CIImageProvider
{
	init(tiff inTiffImage: TIFFImageA)
	{
	}
	
	@objc
	func
	provideImageData(_ ioData: UnsafeMutableRawPointer,
						bytesPerRow inRowbytes: Int,
						origin inX: Int,
								_ inY: Int,
						size inWidth: Int,
							_ inHeight: Int,
						userInfo inInfo: Any?)
	{
		debugLog("provideImageData(bytesPerRow: \(inRowbytes); origin: \(inX), \(inY); size: \(inWidth), \(inHeight)")
	}
}

/**
	Because this is an informal protocol not defined in any Apple header,
	we’ll define it here for completeness (and a place to document it).
*/

@objc
protocol
CIImageProvider
{
	/**
		Comments taken from Objective-C header CoreImage/CIImageProvider.h:
		
		Callee should initialize the given bitmap with the subregion x,y
		width,height of the image. (this subregion is defined in the image's
		local coordinate space, i.e. the origin is the top left corner of
		the image).

		By default, this method will be called to requests the full image
		data regardless of what subregion is needed for the current render.
		All of the image is loaded or none of it is.

		If the `CIImage.providerTileSize` option is specified, then only the
		tiles that are needed are requested.

		Changing the virtual memory mapping of the supplied buffer (e.g. using
		vm_copy() to modify it) will give undefined behavior.
			
		- Parameters:
			- ioData: A pre-allocated buffer to contain the image data for the requested tile.
			- inRowbytes: Bytes per row of the supplied tile buffer.
			- inX: X-coordinate of the origin of the tile in image space.
			- inY: Y-coordinate of the origin of the tile in image space.
			- inWidth: Width of requested tile in image space.
			- inHeight: Height of requested tile in image space.
			- inInfo: Information supplied in CIImage constructor.
	*/
	
	@objc
	func
	provideImageData(_ ioData: UnsafeMutableRawPointer,
						bytesPerRow inRowbytes: Int,
						origin inX: Int,
								_ inY: Int,
						size inWidth: Int,
							_ inHeight: Int,
						userInfo inInfo: Any?)
}
