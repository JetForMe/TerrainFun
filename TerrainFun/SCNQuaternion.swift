//
//  SCNQuaternion.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-27.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import Foundation


import SceneKit

import simd




extension
SCNQuaternion
{
	@inlinable
	init(_ inQ: GLKQuaternion)
	{
		self.init(inQ.x, inQ.y, inQ.z, inQ.w)
	}
	
	init(angle inRadians: CGFloat, axis inAxis: SCNVector3)
	{
		self.init(angle: inRadians, axisX: inAxis.x, axisY: inAxis.y, axisZ: inAxis.z)
	}
	
	init(angle inRadians: CGFloat, axisX inX: CGFloat, axisY inY: CGFloat, axisZ inZ: CGFloat)
	{
		let halfAngle = inRadians * 0.5
		let scale = sin(halfAngle)
		self.init(x: scale * inX, y: scale * inY, z: scale * inZ, w: cos(halfAngle))
	}
	
	static
	func
	+(inLHS: SCNQuaternion, inRHS: SCNQuaternion)
		-> SCNQuaternion
	{
		let l = simd_float4(inLHS)
		let r = simd_float4(inRHS)
		let s = l + r
		return SCNQuaternion(s)
	}
}

extension
simd_quatf
{
	init(angle inRadians: Float, axisX inX: Float, axisY inY: Float, axisZ inZ: Float)
	{
		let halfAngle = inRadians * 0.5
		let scale = sin(halfAngle)
		self.init(ix: scale * inX, iy: scale * inY, iz: scale * inZ, r: cos(halfAngle))
	}
}
