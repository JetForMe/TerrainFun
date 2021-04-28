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
	@State				private	var			controlMode										=	MultiAxisDevice.Mode.model
	
    var
    body: some View
    {
        SceneView(scene: self.layer.scene, pointOfView: self.layer.cameraNode, delegate: PerlinTerrainGeneratorRendererDelegate(view: self))
			.onReceive(self.updateTimer) { inTimer in
				if let node = self.layer.cameraNode
				{
					switch (self.controlMode)
					{
						//	Manipulating the camera is easy, just rotate it and translate it by
						//	appropriately-negated values…
						
						case .camera:
							let zq = simd_quatf(angle: Float(self.multiAxisState.roll) * 0.001, axis: simd_float3(x: 0, y: 0, z: 1))
							let yq = simd_quatf(angle: Float(-self.multiAxisState.yaw) * 0.001, axis: simd_float3(x: 0, y: 1, z: 0))
							let xq = simd_quatf(angle: Float(self.multiAxisState.pitch) * 0.001, axis: simd_float3(x: 1, y: 0, z: 0))
							let qq = xq * yq * zq
							node.simdLocalRotate(by: qq)
							
							let tx = Float(self.multiAxisState.x) * 0.001
							let ty = Float(-self.multiAxisState.y) * 0.001
							let tz = Float(self.multiAxisState.z) * 0.001
							let t = simd_float3(x: tx, y: ty, z: tz)
							node.simdLocalTranslate(by: t)
						
						//	Manipulating the model is a bit harder. We do this by orbiting
						//	the camera around it. Translation is the same, just goes in opposite
						//	directions. But rotation needs to occur about a suitable target
						//	point in the scene, with the rotation axes parallel to the
						//	corresponding camera rotation axis.
						//
						//	TODO: for now, the target point is the world origin. In future, maybe
						//	the first model hit point at the center of the screen is correct.
						
						case .model:
							let wz = node.simdConvertVector(simd_float3(x: 0, y: 0, z: 1), to: self.layer.scene!.rootNode)
							let wy = node.simdConvertVector(simd_float3(x: 0, y: 1, z: 0), to: self.layer.scene!.rootNode)
							let wx = node.simdConvertVector(simd_float3(x: 1, y: 0, z: 0), to: self.layer.scene!.rootNode)
							let zq = simd_quatf(angle: Float(-self.multiAxisState.roll) * 0.001, axis: wz)
							let yq = simd_quatf(angle: Float(self.multiAxisState.yaw) * 0.001, axis: wy)
							let xq = simd_quatf(angle: Float(-self.multiAxisState.pitch) * 0.001, axis: wx)
							let qq = xq * yq * zq
							node.simdRotate(by: qq, aroundTarget: .zero)
							
							let tx = Float(-self.multiAxisState.x) * 0.001
							let ty = Float(self.multiAxisState.y) * 0.001
							let tz = Float(-self.multiAxisState.z) * 0.001
							let t = simd_float3(x: tx, y: ty, z: tz)
							node.simdLocalTranslate(by: t)
					}
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
