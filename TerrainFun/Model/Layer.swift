//
//  Layer.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-22.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import SwiftUI

import CoreLocation
import Foundation


class
Layer : ObservableObject, Identifiable
{
				var			id						:	UUID			=	UUID()
	@Published	var			name					:	String?
	@Published	var			url						:	URL?
	@Published	var			visible					:	Bool			=	true			//	TODO: Perhaps this should be a property of the view. But it should be persisted, and that could get messy.
	@Published	var			projection				:	Projection?
	@Published	var			workingImage			:	CGImage?
}

class
DEMLayer : Layer
{
	init(url inURL: URL)
	{
		super.init()
		self.url = inURL
		self.name = inURL.deletingPathExtension().lastPathComponent
		self.projection = Mars2000()
	}
}

protocol
Projection
{
	/**
		Reverse-project the 2D point inFrom to geodetic (lat/lon) coordinates.
	*/
	
	func
	geodetic(from inFrom: CGPoint)
		-> CLLocationCoordinate2D		//	TODO: Include height of reference ellipsoid
}

/**
	TODO: Get rid of this crap
	
	Temporary projection assuming the full-size MOLA DEM data.
*/

struct
Mars2000 : Projection
{
	func
	geodetic(from inFrom: CGPoint)
		-> CLLocationCoordinate2D
	{
		let lon = inFrom.x *  0.003374120830641 + -180.0		//	Taken from gdalinfo for the MOLA image.
		let lat = inFrom.y * -0.003374120830641 +   90.0
		return CLLocationCoordinate2D(latitude: CLLocationDegrees(lat), longitude: CLLocationDegrees(lon))
	}
}
