//
//  SCNViewFR.swift
//  BeatSaber Editor
//
//  Created by Roderick Mann on 2018-07-04.
//  Copyright © 2018 Latency: Zero, LLC. All rights reserved.
//

import SceneKit

class
SCNViewFR: SCNView
{
	override
	func
	awakeFromNib()
	{
		super.awakeFromNib()
		
		self.backgroundColor = NSColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.25, alpha: 1.0)
		
		//	Create the camera…
		
		self.camera = SCNCamera()
		self.camera.zNear = 0.01
		
		self.cameraNode = SCNNode()
		self.cameraNode.camera = self.camera
		self.cameraNode.position = SCNVector3(x: 10.0, y: 10.0, z: 10.0)
		self.cameraNode.look(at: SCNVector3(0.0, 0.0, 0.0))
	}
	
	override
	func
	viewDidMoveToWindow()
	{
		let trackingArea = NSTrackingArea(rect: self.frame, options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect], owner: self, userInfo: nil)
		addTrackingArea(trackingArea)
	}
	
	override
	var
	acceptsFirstResponder: Bool
	{
		return true
	}
	
	/**
		Vertical scroll moves the camera in and out.
	*/
	
	override
	func
	scrollWheel(with inEvent: NSEvent)
	{
		//	Scroll wheel events provide deltaX/Y/Z. X and Y are horizontal
		//	and vertical, wit negative to the right and down (referenced from
		//	the top of the scroll ball)…
		
//		debugLog("Scroll wheel event: \(inEvent.deltaX), \(inEvent.deltaY), \(inEvent.deltaZ)")

		let delta = inEvent.deltaY
		let zoomDir = SCNVector3(0.0, 0.0, self.zoomScale * delta * abs(delta / 2.0))			//	Zoom in is in negative Z direction
		let zd: float3 = float3(zoomDir)
		self.cameraNode.simdLocalTranslate(by: zd)
	}
	
	/**
		Mouse Handling
	
		left click/drag				Object selection/movement, if pick hit
		middle click/drag			Dolly
		right click/drag			Orbit (or look around?)
			option						Pan
	*/
	
	override
	func
	mouseEntered(with inEvent: NSEvent)
	{
		debugLog("mouseEntered")
//		self.window?.acceptsMouseMovedEvents = true
	}
	
	override
	func
	mouseExited(with inEvent: NSEvent)
	{
		debugLog("mouseExited")
//		self.window?.acceptsMouseMovedEvents = false
		clearHover()
	}
	
	override
	func
	mouseMoved(with inEvent: NSEvent)
	{
//		debugLog("mouseMoved")

		let localPt = convert(inEvent.locationInWindow, from: nil)
		let scene = self.scene as! TerrainEditorScene
	}
	
	func
	clearHover()
	{
		if let lastHover = self.hoverNote
		{
			self.editorDelegate?.editorSceneView(self, unHoverNote: lastHover)
			self.hoverNote = nil
		}
	}
	
	override
	func
	mouseDown(with inEvent: NSEvent)
	{
		debugLog("leftMouseDown")
	}
	
	override
	func
	mouseDragged(with inEvent: NSEvent)
	{
		debugLog("mouseDragged: \(String(describing: inEvent.type))")
	}
	
	override
	func
	mouseUp(with inEvent: NSEvent)
	{
		debugLog("mouseUp")
	}
	
	override
	func
	rightMouseDown(with inEvent: NSEvent)
	{
		debugLog("rightMouseDown")
	}
	
	override
	func
	otherMouseDown(with inEvent: NSEvent)
	{
		debugLog("otherMouseDown: \(inEvent.buttonNumber)")
	}
	

	enum
	DragState
	{
		case none
		case picking
		case panning
		case orbiting
	}
	
	var			cameraNode:			SCNNode!
	var			camera: 			SCNCamera!
	var			zoomScale:			CGFloat					=	-0.25
	var			dragState:			DragState				=	.none
	
	override
	var
	scene: SCNScene?
	{
		didSet
		{
			self.cameraNode.removeFromParentNode()
			self.scene?.rootNode.addChildNode(self.cameraNode)
			self.pointOfView = self.cameraNode
		}
	}
	
	@IBOutlet weak var	editorDelegate:			EditorSceneViewDelegate?
	
					var	hoverNote:				Int?
					{
						didSet(inOldValue)
						{
							if inOldValue != self.hoverNote
							{
								if let ov = inOldValue
								{
									self.editorDelegate?.editorSceneView(self, unHoverNote: ov)
								}
								
								if let nv = self.hoverNote
								{
									self.editorDelegate?.editorSceneView(self, hoverNote: nv)
								}
							}
						}
					}
}


@objc
protocol
EditorSceneViewDelegate : class
{
	func		editorSceneView(_ inView: SCNViewFR, hoverNote inNote: Int)
	func		editorSceneView(_ inView: SCNViewFR, unHoverNote inNote: Int)
}

class
CameraController : SCNCameraController
{
}
