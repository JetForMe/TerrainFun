//
//  GDAL.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-19.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import Foundation



struct
GDAL
{
	enum
	Errors : Error
	{
		case noTransform
	}
	
	enum
	GDALCPLErr : RawRepresentable
	{
		case none
		case debug
		case warning
		case failure
		case fatal
		
		init?(rawValue inValue: UInt32)
		{
			switch (inValue)
			{
				case 0: self = .none
				case 1: self = .debug
				case 2: self = .warning
				case 3: self = .failure
				case 4: self = .fatal
				default: return nil
			}
		}
		
		var rawValue: UInt32
		{
			get
			{
				switch (self)
				{
					case .none: return 0
					case .debug: return 1
					case .warning: return 2
					case .failure: return 3
					case .fatal: return 4
				}
			}
		}
		
		typealias RawValue = UInt32
	}
	
	static
	func
	versionInfo(_ inReq: String)
		-> String
	{
		return String(cString: GDALVersionInfo(inReq))
	}
	
	static
	func
	allRegister()
	{
		GDALAllRegister()
	}
}
