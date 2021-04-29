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
	
	@State	private	var			controlMode										=	MultiAxisDevice.Mode.model
	
    var
    body: some View
    {
        SceneView(scene: self.layer.scene,
					pointOfView: self.layer.cameraNode,
        			options: [.rendersContinuously],			//	We can probably change this with @State to only render continously so long as we're getting movement input
					delegate: PerlinTerrainGeneratorRendererDelegate(layer: self.layer, controlMode: self.controlMode))
    }
}

class
PerlinTerrainGeneratorRendererDelegate : NSObject, SCNSceneRendererDelegate
{
	private	var			layer				:	TerrainGeneratorLayer
	private	var			controlMode			:	MultiAxisDevice.Mode
	
	init(layer inLayer: TerrainGeneratorLayer, controlMode inCM: MultiAxisDevice.Mode)
	{
		self.layer = inLayer
		self.controlMode = inCM
	}
	
    func
    renderer(_ inRenderer: SCNSceneRenderer, updateAtTime inTime: TimeInterval)
    {
//		guard let scene = inRenderer.scene else { return }
		guard let node = self.layer.cameraNode else { return }
    	guard
    		let lastTime = self.lastTime
		else
		{
			self.lastTime = inTime
			return
		}
		
		let deltaT = Float(inTime - lastTime)
		self.lastTime = inTime
		
//    	debugLog("Time interval: \(deltaT, specifier: "%0.3f")")

		//	Some axis constants to clean up the following code…
		
		let xAxis = simd_float3(x: 1.0, y: 0.0, z: 0.0)
		let yAxis = simd_float3(x: 0.0, y: 1.0, z: 0.0)
		let zAxis = simd_float3(x: 0.0, y: 0.0, z: 1.0)
		
		//	Rotate and translate by values dependent on frame rate…
		
		let rotationScale: Float = 0.005
		let translationScale: Float = 0.01
		
		let xr = self.multiAxisInput.state.pitch * rotationScale * deltaT
		let yr = self.multiAxisInput.state.yaw * rotationScale * deltaT
		let zr = self.multiAxisInput.state.roll * rotationScale * deltaT
		
		let xt = self.multiAxisInput.state.x * translationScale * deltaT
		let yt = self.multiAxisInput.state.y * translationScale * deltaT
		let zt = self.multiAxisInput.state.z * translationScale * deltaT
		
		switch (self.controlMode)
		{
			//	Manipulating the camera is easy, just rotate it and translate it by
			//	appropriately-negated values…
			
			case .camera:
				//	Rotate…
				
				let xq = simd_quatf(angle: xr, axis: xAxis)
				let yq = simd_quatf(angle: -yr, axis: yAxis)
				let zq = simd_quatf(angle: zr, axis: zAxis)
				let qq = xq * yq * zq
				node.simdLocalRotate(by: qq)
				
				//	Translate…
				
				let t = simd_float3(x: xt, y: -yt, z: zt)
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
				//	Compute the camera axes in root node coordiantes…
				
				let wx = node.simdConvertVector(xAxis, to: self.layer.scene!.rootNode)
				let wy = node.simdConvertVector(yAxis, to: self.layer.scene!.rootNode)
				let wz = node.simdConvertVector(zAxis, to: self.layer.scene!.rootNode)
				
				//	Rotate…
				
				let xq = simd_quatf(angle: -xr, axis: wx)
				let yq = simd_quatf(angle: yr, axis: wy)
				let zq = simd_quatf(angle: -zr, axis: wz)
				let qq = xq * yq * zq
				node.simdRotate(by: qq, aroundTarget: .zero)
				
				//	Translate…
				
				let t = simd_float3(x: -xt, y: yt, z: -zt)
				node.simdLocalTranslate(by: t)
		}
    }
    
    var				lastTime: TimeInterval?
    let				multiAxisInput											=	MultiAxisDevice.shared
}

struct PerlinTerrainGeneratorView_Previews: PreviewProvider {
    static var previews: some View {
        PerlinTerrainGeneratorView(layer: TerrainGeneratorLayer())
			.environmentObject(MultiAxisDevice.shared)
    }
}
