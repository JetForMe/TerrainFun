//
//  MulitAxisDevice.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-26.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import Foundation
import IOKit
import IOKit.hid
import Combine

/**
	Makes working with USB HID Multiaxis Devices easier (specifically geared toward
	using the 3DConnexion Space Mouse).
	
	TODO: This will probably affect all views that use it; it really should just affect the frontmost.
*/

class
MultiAxisDevice : ObservableObject
{
	static let shared = MultiAxisDevice()
	
	enum
	Mode
	{
		case camera			//	Spacemouse controls camera
		case model			//	Spacemouse controls scene
	}
	
	private
	init()
	{
		self.hidManager = HIDManager.shared
		self.hidManager.delegate = self
	}
	
	let			hidManager			:	HIDManager
	@Published var			state									=	MultiAxisState()
}


extension
MultiAxisDevice : HIDManagerDelegate
{
	func
	deviceValueReceived(device inDevice: HIDDevice, element inElement: IOHIDElement, cookie inCookie: IOHIDElementCookie, code inCode: Int)
	{
//		debugLog("Value callback. element: [\(inElement)], cookie: \(inCookie), code: \(inCode)")
		
		//	SpaceMouse cookie 54 is roll axis
		
		var state = self.state
		
		switch (inCookie)
		{
		case 55:		state.yaw = Float(inCode)
		case 54:		state.roll = Float(inCode)
		case 53:		state.pitch = Float(inCode)
		case 52:		state.y = Float(inCode)
		case 51:		state.z = Float(inCode)
		case 50:		state.x = Float(inCode)
			default:
				break
		}
		
		self.state = state
	}
	
}

struct
MultiAxisState
{
	var			pitch		:	Float		=	0
	var			yaw			:	Float		=	0
	var			roll		:	Float		=	0
	var			x			:	Float		=	0
	var			y			:	Float		=	0
	var			z			:	Float		=	0
}
