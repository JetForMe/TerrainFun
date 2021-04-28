//
//  PerlinTerrainGeneratorView.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-26.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import SwiftUI

import GLKit
import SceneKit

struct
PerlinTerrainGeneratorView: View
{
	let			layer				:	TerrainGeneratorLayer
	var			angle				:	Double = 0.0
	
	@EnvironmentObject	private	var 		multiAxisInput		:	MultiAxisDevice
	@State				private	var			multiAxisState		:	MultiAxisState			=	MultiAxisState()
	
	@State				private	var			updateTimer										=	Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
	
    var
    body: some View
    {
        SceneView(scene: self.layer.scene, pointOfView: self.layer.cameraNode, delegate: PerlinTerrainGeneratorRendererDelegate(view: self))
			.onReceive(self.updateTimer) { inTimer in
				if let ea = self.layer.cameraNode
				{
					let zq = simd_quatf(angle: Float(self.multiAxisState.roll) * 0.001, axis: simd_float3(x: 0, y: 0, z: 1))
					let yq = simd_quatf(angle: Float(-self.multiAxisState.yaw) * 0.001, axis: simd_float3(x: 0, y: 1, z: 0))
					let xq = simd_quatf(angle: Float(self.multiAxisState.pitch) * 0.001, axis: simd_float3(x: 1, y: 0, z: 0))
					let qq = xq * yq * zq
					let q = SCNQuaternion(qq.vector)
					ea.localRotate(by: q)
				}
			}
			.onReceive(self.multiAxisInput.$state) { inState in
				self.multiAxisState = inState
			}
    }
}

class
PerlinTerrainGeneratorRendererDelegate : NSObject, SCNSceneRendererDelegate
{
	init(view inView: PerlinTerrainGeneratorView)
	{
		self.view = inView
	}
	
	let view: PerlinTerrainGeneratorView
}

struct PerlinTerrainGeneratorView_Previews: PreviewProvider {
    static var previews: some View {
        PerlinTerrainGeneratorView(layer: TerrainGeneratorLayer())
			.environmentObject(MultiAxisDevice.shared)
    }
}
