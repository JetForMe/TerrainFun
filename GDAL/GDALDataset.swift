//
//  GDALDataset.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-19.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import Foundation




extension
GDAL			//	For namespacing more than anything
{
	enum
	Access : RawRepresentable
	{
		case readOnly
		case update
		
		init?(rawValue inVal: Int)
		{
			switch (inVal)
			{
				case 0: self = .readOnly
				case 1: self = .update
				default: return nil
			}
		}
		
		var rawValue: Int
		{
			get
			{
				switch (self)
				{
					case .readOnly: return 0
					case .update: return 1
				}
			}
		}
		
		typealias RawValue = Int
		
	}
	
	struct
	Dataset
	{
		init?(path inPath: String, access inAccess: Access = .readOnly)
		{
			if let ds = GDALOpen(inPath, GDALAccess(UInt32(inAccess.rawValue)))
			{
				self.ds = ds
			}
			else
			{
				debugLog("Error opening file: \(CPLGetLastErrorNo())")
				return nil
			}
		}
		
		func
		getGeoTransform()
			throws
			-> GeoTransform
		{
			var txfm = [Double](repeating: 0, count: 6)
			let result = GDALCPLErr(rawValue: GDALGetGeoTransform(self.ds, &txfm).rawValue)!
			if result != .none
			{
				throw Errors.noTransform
			}
			
			return GeoTransform(txfm)
		}
		
		var			rasterCount		:	Int				{ get { return Int(GDALGetRasterCount(self.ds)) } }
		
		func
		getRasterBand(_ inBand: Int)
			-> RasterBand
		{
			let b = RasterBand(GDALGetRasterBand(self.ds, Int32(inBand)))
			return b
		}
		
		
		var			xSize			:	Int				{ get { return Int(GDALGetRasterXSize(self.ds)) } }
		var			ySize			:	Int				{ get { return Int(GDALGetRasterYSize(self.ds)) } }
		
		var			ds				:	GDALDatasetH
	}
}


extension
GDAL
{
	struct
	GeoTransform
	{
		init()
		{
			self.txfm = [0, 1, 0, 0, 0, 1]
		}
		
		init(_ inTxfm: [Double])
		{
			self.txfm = inTxfm
		}
		
		subscript(_ inIdx: Int)
			-> Double
		{
			get { return self.txfm[inIdx] }
		}
		
		let			txfm: [Double]
	}
}

extension
GDAL
{
	struct
	RasterBand
	{
		init(_ inBand: GDALRasterBandH)
		{
			self.rb = inBand
		}
		
		
		var			xSize			:	Int				{ get { return Int(GDALGetRasterBandXSize(self.rb)) } }
		var			ySize			:	Int				{ get { return Int(GDALGetRasterBandYSize(self.rb)) } }
		
		var
		blockSize: (Int, Int)
		{
			get
			{
				var xBS: Int32 = 0
				var yBS: Int32 = 0
				GDALGetBlockSize(self.rb, &xBS, &yBS)
				return (Int(xBS), Int(yBS))
			}
		}
		
		var			minimum			:	Double?					{ get { var gotVal: Int32 = 0; let v = GDALGetRasterMinimum(self.rb, &gotVal); return gotVal != 0 ? v : nil } }
		var			maximum			:	Double?					{ get { var gotVal: Int32 = 0; let v = GDALGetRasterMaximum(self.rb, &gotVal); return gotVal != 0 ? v : nil } }
		
		func
		computeMinMax(approxOK inApprox: Bool = false)
			-> (Double, Double)
		{
			var minMax = [0.0, 0.0]										//	0.0 should be fine as GDAL will always fill in good values
			GDALComputeRasterMinMax(self.rb, inApprox ? 1 : 0, &minMax)
			return (minMax[0], minMax[1])
		}
		
		var		overviewCount		:	Int						{ get { return Int(GDALGetOverviewCount(self.rb)) } }
		
		
		func
		rasterRead(into inPointer: UnsafeMutableRawPointer,
					bufferWidth inBufWidth: Int,
					bufferHeight inBufHeight: Int,
					xOff inXOff: Int,
					yOff inYOff: Int,
					xSize inWidth: Int,
					ySize inHeight: Int,
					//type inType: GDAL.DataType,			//	TODO implement other types
					pixelSpace inPixelSpace: Int = 0,
					lineSpace inLineSpace: Int = 0)
		{
			var ea = GDALRasterIOExtraArg(nVersion: RASTERIO_EXTRA_ARG_CURRENT_VERSION, eResampleAlg: GRIORA_NearestNeighbour, pfnProgress: nil, pProgressData: nil, bFloatingPointWindowValidity: 0, dfXOff: 0, dfYOff: 0, dfXSize: 0, dfYSize: 0)
			let err = GDALRasterIOEx(self.rb,
									GF_Read,
									Int32(UInt32(inXOff)), Int32(inYOff),
									Int32(inWidth), Int32(inHeight),
									inPointer,
									Int32(inBufWidth), Int32(inBufHeight), GDT_Int16,
									GSpacing(inPixelSpace), GSpacing(inLineSpace),
									&ea)
			let result = GDALCPLErr(rawValue:  err.rawValue)!
			if result != .none
			{
				debugLog("Error reading raster data")
			}
		}
					
		private var			rb				:	GDALRasterBandH!
	}
}
