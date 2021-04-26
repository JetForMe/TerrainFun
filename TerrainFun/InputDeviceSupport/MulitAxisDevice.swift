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
		
		switch (inCookie)
		{
			case 54:		self.state.roll = inCode
			default:
				break
		}
	}
	
}

struct
MultiAxisState
{
	var			roll		:	Int		=	0
}
