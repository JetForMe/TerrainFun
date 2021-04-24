//
//  ViewController.swift
//  TerrainFun
//
//  Created by Rick Mann on 2020-07-22.
//  Copyright © 2020 Latency: Zero, LLC. All rights reserved.
//

import Cocoa
import SceneKit

class
ViewController: NSViewController
{
	override
	func
	viewDidLoad()
	{
		super.viewDidLoad()
		
		let scene = TerrainEditorScene()
		self.sceneView.scene = scene
	}

	override var representedObject: Any? {
		didSet {
		// Update the view, if already loaded.
		}
	}

	
	@IBOutlet weak var sceneView: SCNView!
}

