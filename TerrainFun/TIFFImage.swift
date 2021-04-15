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
	
	Known Bugs:
		• I’ve played fast and loose with Int-vs-Int64 and subscripts. While it’s
			unlikely that on 64-bit systems any real data will exceed Int.maxValue,
			there are places where this code ignores those distinctions that will
			likely fail.
		
	
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
		case noImage
	}
	
	enum FormatVersion : UInt16
	{
		case v42			=	42					//	Original TIFF, 32-bit offsets
		case v43			=	43					//	BigTIFF, 64-bit offsets
	}
	
	init(contentsOfURL inURL: URL)
		throws
	{
		self.reader = try BinaryFileReader(url: inURL)
		try readHeader()
	}
	
	mutating
	func
	readHeader()
		throws
	{
		let endian: UInt16 = try self.reader.get()				//	Bytes 0-1 (endian)
		self.reader.bigEndian = endian == 0x4d4d
		let formatVersion: UInt16 = try self.reader.get()			//	Bytes 2-3 (format version)
		if formatVersion == 42
		{
			self.formatVersion = .v42
		}
		else if formatVersion == 43
		{
			self.formatVersion = .v43
			let offsetByteSize: UInt16 = try self.reader.get()	//	Bytes 4-5, offset size, currently only size==8 supported
			if offsetByteSize != 8
			{
				throw Error.invalidOffsetSize(Int(offsetByteSize))
			}
			self.offsetSize = Int(offsetByteSize)
			let padding: UInt16 = try self.reader.get()			//	Bytes 6-7, should be zero
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
		
		let offset = try readOffset()
		try self.reader.seek(to: offset)
		
		var ifd = IFD()
		let entryCount = try readEntryCount()
		for _ in 0 ..< entryCount
		{
			let de = try readDirectoryEntry()
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
					let values = try de.validateInt(count: 1)
					ifd.width =  UInt32(values.first!)		//	TODO: Are we sure we can't exceed UInt32? we should still do Int64, no?
				
				case .imageLength:
					let values = try de.validateInt(count: 1)
					ifd.height = UInt32(values.first!)
				
				case .bitsPerSample:
					let values = try de.validateInt(count: 1)
					ifd.bitsPerSample = UInt16(values.first!)
					
				case .compression:
					let values = try de.validateInt(count: 1)
					ifd.compression = try CompressionType.from(rawValue: UInt16(values.first!))
				
				case .photometricInterpretation:
					let values = try de.validateInt(count: 1)
					ifd.blackIsZero = values.first! != 0
					
				case .stripOffsets:
					//	TODO: If there's a single strip offset, it's probably stored in the offset. Same is true for byte counts, etc.
					let offset = try de.validateOffset()
					try self.reader.at(offset: offset)
					{
						ifd.stripOffsets = try read(count: de.count, ofType: de.type)
					}
				
				case .samplesPerPixel:
					ifd.samplesPerPixel = try de.validateUInt16()
				
				case .rowsPerStrip:
					ifd.rowsPerStrip = try de.validateUInt32()
					break
				
				case .stripByteCounts:
					let offset = try de.validateOffset()
					try self.reader.at(offset: offset)
					{
						ifd.stripByteCounts = try read(count: de.count, ofType: de.type)
					}
				
				case .xResolution:
					let res: Rational = try self.reader.get()
					debugLog("xres: \(res)")
				
				case .planarConfiguration:
					ifd.planarConfiguration = try de.validateUInt16()
				
				case .predictor:
					let values = try de.validateInt(count: 1)
					ifd.predictor = try Predictor.from(rawValue: UInt16(values.first!))
					
				case .tileWidth:
					ifd.tileWidth = try de.validateUInt32()
					
				case .tileLength:
					ifd.tileLength = try de.validateUInt32()
				
				case .tileOffsets:
					let offset = try de.validateOffset()
					try self.reader.at(offset: offset)
					{
						ifd.tileOffsets = try read(count: de.count, ofType: de.type)
					}
					
				case .tileByteCounts:
					let offset = try de.validateOffset()
					try self.reader.at(offset: offset)
					{
						ifd.tileByteCounts = try read(count: de.count, ofType: de.type)
					}
					
				case .sampleFormat:
					ifd.sampleFormat = SampleFormat.from(rawValue: try de.validateUInt16())
				
				case .modelPixelScale:
					let offset = try de.validateOffset()
					try self.reader.at(offset: offset)
					{
						//	Read three doubles…
						
						ifd.scaleX = try self.reader.get()
						ifd.scaleY = try self.reader.get()
						ifd.scaleZ = try self.reader.get()
					}
				
				case .modelTiePoint:
					let offset = try de.validateOffset()
					try self.reader.at(offset: offset)
					{
						//	Read N*6 doubles (N is number of tie points)…
						
						let tiePointCount = de.count / 6
						for _ in 0..<tiePointCount
						{
							let mtp = ModelTiePoint(i: try self.reader.get(),
													j: try self.reader.get(),
													k: try self.reader.get(),
													x: try self.reader.get(),
													y: try self.reader.get(),
													z: try self.reader.get())
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
					
					let offset = try de.validateOffset()
					try self.reader.at(offset: offset)
					{
						//	Read the header information…
						
						let keyDirectoryVersion: UInt16 = try self.reader.get()
						if keyDirectoryVersion != 1
						{
							//	TODO: Better to throw an exception here?
							debugLog("Unknown key directory version (\(keyDirectoryVersion)).")
							return
						}
						
						let keyRevision: UInt16 = try self.reader.get()
						let minorVersion: UInt16 = try self.reader.get()
						debugLog("Key revision: \(keyRevision).\(minorVersion)")
						
						let keyCount: UInt16 = try self.reader.get()
						
						//	We should not have more keys than the count of the directory
						//	entry would allow…
						
						assert(de.count >= keyCount * 4 + 4, "de.count (\(de.count)) < \(keyCount * 4 + 4)")
						//	TODO: Handle the excess data in this Entry.
						
						//	Read each key…
						
						for _ in 0..<keyCount
						{
							let geoKey = try readGeoKeyEntry()
							ifd.geoKeyEntries.append(geoKey)
							debugLog("\(geoKey)")
						}
					}
				
				case .geoDoubleParams:
					let offset = try de.validateOffset()
					try self.reader.at(offset: offset)
					{
						ifd.geoDoubleParams = try self.reader.get(count: Int(de.count))
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
		
		let nextOffset: UInt32 = try self.reader.get()
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
		throws
		-> Int64
	{
		let offset: Int64
		switch (self.formatVersion)
		{
			case .v42:
				let v42Offset: UInt32 = try self.reader.get()
				offset = Int64(v42Offset)
			
			case .v43:
				offset = try self.reader.get()
		}
		
		return offset
	}
	
	/**
		The entry count is 16 bit for TIFF v42, 64-bit for v43 (BigTIFF)…
	*/
	
	mutating
	func
	readEntryCount()
		throws
		-> Int64
	{
		let offset: Int64
		switch (self.formatVersion)
		{
			case .v42:
				let v42Count: UInt16 = try self.reader.get()
				offset = Int64(v42Count)
			
			case .v43:
				offset = try self.reader.get()
		}
		
		return offset
	}
	
	mutating
	func
	readTagCount()
		throws
		-> Int64
	{
		let offset: Int64
		switch (self.formatVersion)
		{
			case .v42:
				let v42Count: UInt32 = try self.reader.get()
				offset = Int64(v42Count)
			
			case .v43:
				offset = try self.reader.get()
		}
		
		return offset
	}
	
	mutating
	func
	read(count inCount: Int64, ofType inType: TagType)
		throws
		-> [Int64]
	{
		if inType == .short
		{
			let v: [UInt16] = try self.reader.get(count: Int(inCount))
			return v.map { Int64($0) }
		}
		else if inType == .long
		{
			let v: [UInt32] = try self.reader.get(count: Int(inCount))
			return v.map { Int64($0) }
		}
		else if inType == .long8
		{
			let v: [Int64] = try self.reader.get(count: Int(inCount))
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
			let s: String = try self.reader.at(offset: inDE.location + 4 + Int64(self.offsetSize))
			{
				if let s: String = try self.reader.get(count: Int(inDE.count) - 1)		//	Exclude trailing NULL
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
			let offset = try inDE.validateOffset()
			let s: String = try self.reader.at(offset: offset)
			{
				if let s: String = try self.reader.get(count: Int(inDE.count) - 1)		//	Exclude trailing NULL
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
		throws
		-> DirectoryEntry
	{
		let loc = self.reader.idx
		let tagV: UInt16 = try self.reader.get()
		let tag = Tag.from(rawValue: tagV)
		let tagTypeV: UInt16 = try self.reader.get()
		let tagType = TagType.from(rawValue: tagTypeV)
		
		let count = try readTagCount()
		
		//	If the size of the data fits in the last field
		//	(less than four or eight bytes, depending on format),
		//	read it now…
		
		let values: DirectoryEntry.Value?
		let offset: Int64?
		
		if count * Int64(tagType.size) <= self.offsetSize
		{
			offset = nil
			
			values = try readValues(type: tagType, count: count)
			
			//	Seek to the byte after this DirectoryEntry, to be sure
			//	we’re pointing to the next one, since we might not have
			//	read all the bytes in this one…
			
			if self.formatVersion == .v42
			{
				try self.reader.seek(to: loc + Int64(TagType.ifd.size))
			}
			else if self.formatVersion == .v43
			{
				try self.reader.seek(to: loc + Int64(TagType.ifd8.size))
			}
			else
			{
				//	Can't be anything else.
			}
		}
		else
		{
			//	The offset field contains an offset…
			
			values = nil
			offset = try readOffset()
		}
		
		let de = DirectoryEntry(location: Int64(loc),
								tag: tag,
								type: tagType,
								count: count,
								values: values,
								offset: offset)
		//	TODO: In big endian, this offset read fails for some types.
		//		If there's a count of 1 short value, the two bytes that make up
		//		that value are the first two bytes of the offset field. We need
		//		to check that the values fit in the field, read them if they do,
		//		store them in an optional array in the DirectoryEntry, *OR* store
		//		the offset.
		
		return de
	}
	
	func
	readValues(type inTagType: TagType, count inCount: Int64)
		throws
		-> DirectoryEntry.Value
	{
		let values: DirectoryEntry.Value
		switch (inTagType)
		{
			case .byte, .short, .long, .long8:
				var vv = [Int64]()
				for _ in 0 ..< inCount
				{
					switch (inTagType)
					{
						case .byte:		let v: UInt8 = try self.reader.get();	vv.append(Int64(v));	break
						case .short:	let v: UInt16 = try self.reader.get();	vv.append(Int64(v));	break
						case .long:		let v: UInt32 = try self.reader.get();	vv.append(Int64(v));	break
						case .long8:	let v: Int64 = try self.reader.get();	vv.append(Int64(v));	break
						default: fatalError()
					}
				}
				values = .int(vv)
				
			case .sbyte, .sshort, .slong, .slong8:
				var vv = [Int64]()
				for _ in 0 ..< inCount
				{
					switch (inTagType)
					{
						case .sbyte:	let v: Int8 = try self.reader.get();	vv.append(Int64(v));	break
						case .sshort:	let v: Int16 = try self.reader.get();	vv.append(Int64(v));	break
						case .slong:	let v: Int32 = try self.reader.get();	vv.append(Int64(v));	break
						case .slong8:	let v: Int64 = try self.reader.get();	vv.append(Int64(v));	break
						default: fatalError()
					}
				}
				values = .int(vv)
			
			case .float, .double:
				var vv = [Double]()
				for _ in 0 ..< inCount
				{
					switch (inTagType)
					{
						case .float:	let v: Float = try self.reader.get();	vv.append(Double(v));	break
						case .double:	let v: Double = try self.reader.get();	vv.append(Double(v));	break
						default: fatalError()
					}
				}
				values = .double(vv)
			
			case .rational:
				var vv = [SRational8]()
				for _ in 0 ..< inCount
				{
					let v: Rational = try self.reader.get()
					vv.append(SRational8(v))
				}
				values = .rational(vv)
			
			case .srational:
				var vv = [SRational8]()
				for _ in 0 ..< inCount
				{
					let v: SRational = try self.reader.get()
					vv.append(SRational8(v))
				}
				values = .rational(vv)
				
			case .ascii:
				//	TODO: TIFF allows embedding NULL characters to indicate multiple strings.
				if let s: String = try self.reader.get(count: Int(inCount) - 1)		//	Exclude trailing NULL
				{
//					debugLog("String '\(s)'")
					values = .ascii(s)
				}
				else
				{
					throw Error.invalidTIFFFormat
				}
			
			case .undefined:
				assert(false, "Not implemented yet")
				return .undefined(Data())
				
			default:
				throw Error.invalidTIFFFormat
		}
		
		return values
	}
	
	/**
		Reads a GeoKeyEntry at the current reader index.
	*/
	
	mutating
	func
	readGeoKeyEntry()
		throws
		-> GeoKeyEntry
	{
		let kv: UInt16 = try self.reader.get()
		let geoKey = GeoKey.from(rawValue: kv)
		let tagV: UInt16 = try self.reader.get()
		let gke = GeoKeyEntry(key: geoKey,
								tagLoc: tagV == 0 ? Tag.none : Tag.from(rawValue: tagV),
								count: try self.reader.get(),
								valueOffset: try self.reader.get())
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
			let v: UInt16 = try self.reader.at(offset: Int64(offset))
			{
				let v: UInt16 = try self.reader.get()
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
		Read a row of pixel data.
	*/
	
//	func
//	read(row inY: Int64, startX inStartX: Int64, width inWidth: Int64)
//		throws
//		-> Data
//	{
//		guard let ifd = self.ifd else { throw Error.noImage }
//
//		let stripIndex = inY / Int64(ifd.rowsPerStrip)
//		let stripOffset = ifd.stripOffsets[Int(stripIndex)]
//		//	TODO: validate coordinates in strip (especially last strip)
////		let stripByteCount = ifd.stripByteCounts[Int(stripIndex)]
//		let rowInStrip = inY % Int64(ifd.rowsPerStrip)
//		let rowBytes = ifd.width * 2
//
//		let bytesPerPixel = Int64(ifd.samplesPerPixel * ifd.bitsPerSample / 8)
//		let startIndex = stripOffset + rowInStrip * Int64(rowBytes) + inStartX * bytesPerPixel
//		let endIndex = startIndex + inWidth * bytesPerPixel
//
//		let data = try self.reader.data[startIndex ..< endIndex]
//		return data
//	}
	
	func
	read(into inBuf: UnsafeMutableRawBufferPointer, row inY: Int64, startX inStartX: Int64)
		throws
		-> Int
	{
		guard let ifd = self.ifd else { throw Error.noImage }
		
		let stripIndex = inY / Int64(ifd.rowsPerStrip)
		let stripOffset = ifd.stripOffsets[Int(stripIndex)]
		//	TODO: validate coordinates in strip (especially last strip)
//		let stripByteCount = ifd.stripByteCounts[Int(stripIndex)]
		let rowInStrip = inY % Int64(ifd.rowsPerStrip)
		
		let bytesPerPixel = Int64(ifd.samplesPerPixel * ifd.bitsPerSample / 8)
		let rowBytes = Int64(ifd.width) * bytesPerPixel
		
		let startIndex = stripOffset + rowInStrip * Int64(rowBytes) + inStartX * bytesPerPixel
		
		return try self.reader.read(fromAbsoluteOffset: startIndex, into: inBuf)
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
		var		stripByteCounts			:	[Int64]					=	[Int64]()
		var		stripOffsets			:	[Int64]					=	[Int64]()
		var		stripShortData			:	[[UInt16]?]?
		
		var		stripCount				:	Int64						{ get { return Int64((self.height + 1) / self.rowsPerStrip) } }
																		//	Adding one to the height ensures that with integer division,
																		//	the result includes any final partial strip.
		
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
		var		tileOffsets				:	[Int64]					=	[Int64]()
		var		tileByteCounts			:	[Int64]					=	[Int64]()
		
		var		sampleFormat			:	SampleFormat				=	.unknown(0)
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
	SRational : CustomDebugStringConvertible
	{
		let		numerator		:	Int32
		let		denominator		:	Int32
		
		var debugDescription: String
		{
			return "\(self.numerator) / \(self.denominator) = \(Double(self.numerator) / Double(self.denominator)))"
		}
	}
	
	struct
	SRational8 : CustomDebugStringConvertible
	{
		let		numerator		:	Int64
		let		denominator		:	Int64
		
		init()
		{
			self.numerator = 0
			self.denominator = 1
		}
		
		init(_ inV: Rational)
		{
			self.numerator = Int64(inV.numerator)
			self.denominator = Int64(inV.denominator)
		}
		
		init(_ inV: SRational)
		{
			self.numerator = Int64(inV.numerator)
			self.denominator = Int64(inV.denominator)
		}
		
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
		enum
		Value
		{
			case int([Int64])
			case rational([SRational8])
			case double([Double])
			case ascii(String)
			case undefined(Data)
		}
		
		let		location			:	Int64			//	Location in file of this Entry
		let		tag					:	Tag
		let		type				:	TagType
		let		count				:	Int64
		let		values				:	Value?
		let		offset				:	Int64?
		
		//	TODO: This returns an array. Should we name it as such?
		func
		validateInt(count inCount: Int64)
			throws
			-> [Int64]
		{
			guard
				case let .int(values) = self.values,
				self.count == inCount
			else
			{
				throw Error.invalidTIFFFormat
			}
			
			return values
		}
		
		func
		validateOffset()
			throws
			-> Int64
		{
			guard
				let offset = self.offset
			else
			{
				throw Error.invalidTIFFFormat
			}
			
			return offset
		}
		
		/**
		*/
		
		func
		validateUInt16()
			throws
			-> UInt16
		{
			guard
				self.count == 1,
				self.type == .byte || self.type == .short,// || self.type == .long
				case let .int(values) = self.values
			else
			{
				throw Error.tagTypeConversionError
			}
			return UInt16(values.first!)
		}

		/**
		*/
		
		func
		validateUInt32()
			throws
			-> UInt32
		{
			guard
				self.count == 1,
				self.type == .byte || self.type == .short || self.type == .long,
				case let .int(values) = self.values
			else
			{
				throw Error.tagTypeConversionError
			}
			return UInt32(values.first!)
		}

//		func
//		uint64()
//			throws
//			-> UInt64
//		{
//			if self.type == .byte || self.type == .short || self.type == .long || self.type == .long8
//			{
//				return self.offset
//			}
//
//			throw Error.tagTypeConversionError
//		}
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
		from(rawValue inVal: UInt16)
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
		
		case none													//	For GeoKeys
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
	
	struct
	TagType : Equatable, CustomStringConvertible
	{
		static func == (lhs: TIFFImageA.TagType, rhs: TIFFImageA.TagType) -> Bool {
			return lhs.rawValue == rhs.rawValue
		}
		
		let			rawValue		:	UInt16
		let			size			:	UInt8				//	Size in file, not Swift type size
		let			type			:	Any.Type
		let			description			:	String
		
		static let	byte			=	TagType(rawValue: 1, size: 1, type: UInt8.self, description: "byte")
		static let	ascii			=	TagType(rawValue: 2, size: 1, type: UInt8.self, description: "ascii")
		static let	short			=	TagType(rawValue: 3, size: 2, type: UInt16.self, description: "short")
		static let	long			=	TagType(rawValue: 4, size: 4, type: UInt32.self, description: "long")
		static let	rational		=	TagType(rawValue: 5, size: 8, type: Rational.self, description: "rational")

		static let	sbyte			=	TagType(rawValue: 6, size: 1, type: Int8.self, description: "sbyte")
		static let	undefined		=	TagType(rawValue: 7, size: 1, type: UInt8.self, description: "undefined")
		static let	sshort			=	TagType(rawValue: 8, size: 2, type: Int16.self, description: "sshort")
		static let	slong			=	TagType(rawValue: 9, size: 4, type: Int32.self, description: "slong")
		static let	srational		=	TagType(rawValue: 10, size: 8, type: SRational.self, description: "srational")

		static let	float			=	TagType(rawValue: 11, size: 4, type: Float.self, description: "float")
		static let	double			=	TagType(rawValue: 12, size: 8, type: Double.self, description: "double")
		
		static let	ifd				=	TagType(rawValue: 13, size: 12, type: IFD.self, description: "ifd")
		
		//	BigTIFF Types
		
		static let	long8			=	TagType(rawValue: 16, size: 8, type: Int64.self, description: "long8")
		static let	slong8			=	TagType(rawValue: 17, size: 8, type: UInt64.self, description: "slong8")
		static let	ifd8			=	TagType(rawValue: 18, size: 20, type: IFD.self, description: "ifd8")
		
		static
		func
		from(rawValue inValue: UInt16)
			-> TagType
		{
			switch (inValue)
			{
				case Self.byte.rawValue: return .byte
				case Self.ascii.rawValue: return .ascii
				case Self.short.rawValue: return .short
				case Self.long.rawValue: return .long
				case Self.rational.rawValue: return .rational
				
				case Self.sbyte.rawValue: return .sbyte
				case Self.undefined.rawValue: return .undefined
				case Self.sshort.rawValue: return .sshort
				case Self.slong.rawValue: return .slong
				case Self.srational.rawValue: return .srational
				
				case Self.float.rawValue: return .float
				case Self.double.rawValue: return .double
				case Self.ifd.rawValue: return .ifd
				
				case Self.long8.rawValue: return .long8
				case Self.slong8.rawValue: return .slong8
				case Self.ifd8.rawValue: return .ifd8

				default:
					return TagType(rawValue: inValue, size: 1, type: Void.self, description: "Uknown(\(inValue))")
			}
		}
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
		from(rawValue inVal: UInt16)
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
	SampleFormat
	{
		case unknown(UInt16)
		case unsignedInt
		case signedInt
		case float
		case void
		case complexInt
		case complextFloat
		
		static
		func
		from(rawValue inV: UInt16)
			-> SampleFormat
		{
			switch (inV)
			{
				case 1:		return .unsignedInt
				case 2:		return .signedInt
				case 3:		return .float
				case 4:		return .void
				case 5:		return .complexInt
				case 6:		return .complextFloat
				default:	return .unknown(inV)
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
	var			reader				:	BinaryFileReader
	var			directoryEntries						=	[Tag:DirectoryEntry]()
	var			ifd					:	IFD?
}



extension
BinaryReader
{
	@inlinable
	func
	get()
		-> TIFFImageA.Rational
	{
		let n: UInt32 = get()
		let d: UInt32 = get()
		return TIFFImageA.Rational(numerator: n, denominator: d)
	}
	
	@inlinable
	func
	get()
		-> TIFFImageA.SRational
	{
		let n: Int32 = get()
		let d: Int32 = get()
		return TIFFImageA.SRational(numerator: n, denominator: d)
	}
}

extension
BinaryFileReader
{
	@inlinable
	func
	get()
		throws
		-> TIFFImageA.Rational
	{
		let n: UInt32 = try get()
		let d: UInt32 = try get()
		return TIFFImageA.Rational(numerator: n, denominator: d)
	}
	
	@inlinable
	func
	get()
		throws
		-> TIFFImageA.SRational
	{
		let n: Int32 = try get()
		let d: Int32 = try get()
		return TIFFImageA.SRational(numerator: n, denominator: d)
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
		self.tiffImage = inTiffImage
	}
	
	/**
		Moves the BinaryReader index.
		
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
	{
		let startTime = CFAbsoluteTimeGetCurrent()
		debugLog("provideImageData(bytesPerRow: \(inRowbytes); origin: \(inX), \(inY); size: \(inWidth), \(inHeight) @ \(startTime)")
		
		defer
		{
			let endTime = CFAbsoluteTimeGetCurrent()
			let delta = endTime - startTime
			debugLog("  took time: \(delta) @ \(endTime)")
		}
		
		do
		{
			let destinationByteCount = inHeight * inRowbytes
			let dest = UnsafeMutableRawBufferPointer(start: ioData, count: destinationByteCount)
			
			let originX = Int64(inX)
			let originY = Int64(inY)
			let width = Int64(inWidth)
			
			//	Find the first strip needed…
			
			guard let ifd = self.tiffImage.ifd else { return }
			let bytesPerPixel = ifd.samplesPerPixel * ifd.bitsPerSample / 8
			for row in 0 ..< Int64(inHeight)
			{
				let y = originY + row
//				let stripIndex = y / UInt64(ifd.rowsPerStrip)
//				let stripOffset = ifd.stripOffsets[Int(stripIndex)]
				
				
				//	Make a new UMRBP to point to the desired slice of the destination…
				//	TODO: Handle endianness differences!!
				
				let bpStart = Int(row * Int64(inRowbytes))
				let bpEnd = bpStart + inWidth * Int(bytesPerPixel)
				let destSlice = UnsafeMutableRawBufferPointer(rebasing: dest[bpStart..<bpEnd])
				let bytesRead = try self.tiffImage.read(into: destSlice, row: y, startX: originX)
				assert(bytesRead == width * Int64(bytesPerPixel))
			}
		}
		
		catch (let e)
		{
			debugLog("Error reading image data \(e)")
		}
	}
	
	let			tiffImage			:	TIFFImageA
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
