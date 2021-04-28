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
		debugLog("Value callback. element: [\(inElement)], cookie: \(inCookie), code: \(inCode)")
		
		//	SpaceMouse cookie 54 is roll axis
		
		var state = self.state
		
		switch (inCookie)
		{
			case 55:		state.yaw = inCode
			case 54:		state.roll = inCode
			case 53:		state.pitch = inCode
			default:
				break
		}
		
		self.state = state
	}
	
}

struct
MultiAxisState
{
	var			pitch		:	Int		=	0
	var			yaw			:	Int		=	0
	var			roll		:	Int		=	0
}
