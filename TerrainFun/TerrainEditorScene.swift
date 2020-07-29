//
//  TerrainEditorScene.swift
//  TerrainFun
//
//  Created by Rick Mann on 2020-07-23.
//  Copyright © 2020 Latency: Zero, LLC. All rights reserved.
//

import SceneKit

class
TerrainEditorScene: SCNScene
{
	override
	init()
	{
		super.init()
		setup()
	}
	
	required
	init?(coder inDecoder: NSCoder)
	{
		fatalError("init(coder:) has not been implemented")
	}
	
	func
	setup()
	{
		//	Orient and scale the world…
		
//		self.rootNode.scale = SCNVector3(10.0, 10.0, 10.0)
//		self.rootNode.eulerAngles = SCNVector3(0.0.degreesToRadians, 0.0, 0.0)
		
		//	Debugging axes…
		
		let axes = setupCoordinateAxes()
		self.rootNode.addChildNode(axes)

		//	Temp geometry…
		
		let box = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.05)
		box.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
		let boxNode = SCNNode(geometry: box)
		self.rootNode.addChildNode(boxNode)
		
	}

	func
	setupCoordinateAxes()
		-> SCNNode
	{
		let axesNode = SCNNode()
		
		//	X…
		
		let axisLength			=	CGFloat(3.0)
		let axisRadius			=	CGFloat(0.05)

		let xAxisNode = SCNNode()
		xAxisNode.eulerAngles = SCNVector3(0.0 * Double.degToRad, 0.0 * Double.degToRad, -90.0 * Double.degToRad)
		
		axesNode.addChildNode(xAxisNode)
		xAxisNode.geometry = SCNCylinder(radius: axisRadius, height: axisLength * 2.0)
		
		let xAxisConeNode = SCNNode()
		xAxisNode.addChildNode(xAxisConeNode)
		xAxisConeNode.geometry = SCNCone(topRadius: 0.0, bottomRadius: 2 * axisRadius, height: 4 * axisRadius)
		xAxisConeNode.position = SCNVector3(0.0, axisLength, 0.0)
		
		var mat = SCNMaterial()
		mat.diffuse.contents = NSColor.red
		xAxisConeNode.geometry?.materials = [mat]
		xAxisNode.geometry?.materials = [mat]
		
		//	X-axis ball…
		
		let xAxisBallNode = SCNNode()
		xAxisBallNode.localTranslate(by: SCNVector3(x: 0.8 * axisLength, y: 0.0, z: 0.0))
		xAxisBallNode.geometry = SCNSphere(radius: 2 * axisRadius)
//		scene.rootNode.addChildNode(xAxisBallNode)
		xAxisBallNode.geometry?.materials = [mat]
		
		//	Y…
		
		let yAxisNode = SCNNode()
		yAxisNode.eulerAngles = SCNVector3(0.0 * Double.degToRad, 0.0 * Double.degToRad, 0.0 * Double.degToRad)
		
		axesNode.addChildNode(yAxisNode)
		yAxisNode.geometry = SCNCylinder(radius: axisRadius, height: axisLength * 2.0)
		
		let yAxisConeNode = SCNNode()
		yAxisNode.addChildNode(yAxisConeNode)
		yAxisConeNode.geometry = SCNCone(topRadius: 0.0, bottomRadius: 2 * axisRadius, height: 4 * axisRadius)
		yAxisConeNode.position = SCNVector3(0.0, axisLength, 0.0)
		
		mat = SCNMaterial()
		mat.diffuse.contents = NSColor.green
		yAxisConeNode.geometry?.materials = [mat]
		yAxisNode.geometry?.materials = [mat]
		
		//	Y-axis ball…
		
		let yAxisBallNode = SCNNode()
		yAxisBallNode.localTranslate(by: SCNVector3(x: 0.0, y: 0.8 * axisLength, z: 0.0))
		yAxisBallNode.geometry = SCNSphere(radius: 2 * axisRadius)
//		scene.rootNode.addChildNode(yAxisBallNode)
		yAxisBallNode.geometry?.materials = [mat]
		
		//	Z…
		
		let zAxisNode = SCNNode()
		zAxisNode.eulerAngles = SCNVector3(90.0 * Double.degToRad, 0.0 * Double.degToRad, 0.0 * Double.degToRad)
		
		axesNode.addChildNode(zAxisNode)
		zAxisNode.geometry = SCNCylinder(radius: axisRadius, height: axisLength * 2.0)
		
		let zAxisConeNode = SCNNode()
		zAxisNode.addChildNode(zAxisConeNode)
		zAxisConeNode.geometry = SCNCone(topRadius: 0.0, bottomRadius: 2 * axisRadius, height: 4 * axisRadius)
		zAxisConeNode.position = SCNVector3(0.0, axisLength, 0.0)
		
		mat = SCNMaterial()
		mat.diffuse.contents = NSColor(red: 0.3, green: 0.3, blue: 1.0, alpha: 1.0)
		zAxisConeNode.geometry?.materials = [mat]
		zAxisNode.geometry?.materials = [mat]
		
		//	Z-axis ball…
		
		let zAxisBallNode = SCNNode()
		zAxisBallNode.localTranslate(by: SCNVector3(x: 0.0, y: 0.0, z: 0.8 * axisLength))
		zAxisBallNode.geometry = SCNSphere(radius: 2 * axisRadius)
//		scene.rootNode.addChildNode(zAxisBallNode)
		zAxisBallNode.geometry?.materials = [mat]
		
		return axesNode
	}
	
}
