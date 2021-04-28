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
import SceneKit



class
Layer : ObservableObject, Identifiable
{
				var			id						:	UUID			=	UUID()
	@Published	var			name					:	String?
	@Published	var			url						:	URL?
	@Published	var			visible					:	Bool			=	true			//	TODO: Perhaps this should be a property of the view. But it should be persisted, and that could get messy.
	@Published	var			projection				:	Projection?
	@Published	var			sourceSize				:	CGSize?
	@Published	var			workingImage			:	CGImage?
	@Published	var			scene					:	SCNScene?
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

class
TerrainGeneratorLayer : Layer
{
	override
	init()
	{
		super.init()
		self.name = "Terrain Generator"
		self.projection = Mars2000()
		
		//	Create a test scene…
		
		self.scene = SCNScene()
		
		//	Create the camera…
		
		let camera = SCNCamera()
		camera.zNear = 0.01
		
		let cameraNode = SCNNode()
		cameraNode.camera = camera
		cameraNode.position = SCNVector3(x: 10.0, y: 10.0, z: 10.0)
		cameraNode.look(at: SCNVector3(0.0, 0.0, 0.0))
		self.cameraNode = cameraNode
		self.scene?.rootNode.addChildNode(cameraNode)
		
		//	Create some geometry…
		
		let axesNode = TerrainEditorScene.setupCoordinateAxes()
		self.scene?.rootNode.addChildNode(axesNode)
	}

	var			cameraNode			:	SCNNode!
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
