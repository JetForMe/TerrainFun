//
//  PerlinTerrainGeneratorView.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-26.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import SwiftUI

import SceneKit

struct
PerlinTerrainGeneratorView: View
{
	var			scene				:	SCNScene//				=	SCNScene(named: "TempScene")
	var			cameraNode			:	SCNNode?	{ self.scene.rootNode.childNode(withName: "camera", recursively: false) }
	
	@ObservedObject	var			multiAxisInput									=	MultiAxisDevice()
	@State	private	var			multiAxisState		:	MultiAxisState			=	MultiAxisState()
	
	let			updateTimer	= Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
	
	init()
	{
		self.scene = SCNScene()
		let axesNode = TerrainEditorScene.setupCoordinateAxes()
		self.scene.rootNode.addChildNode(axesNode)
	}
	
    var
    body: some View
    {
        SceneView(scene: self.scene, pointOfView: self.cameraNode)
			.onReceive(self.updateTimer) { inTimer in
				debugLog("timer")
			}
//			.onReceive(self.multiAxisInput.state) { inState in
//				self.multiAxisState = inState
//			}
    }
}

struct PerlinTerrainGeneratorView_Previews: PreviewProvider {
    static var previews: some View {
        PerlinTerrainGeneratorView()
    }
}
