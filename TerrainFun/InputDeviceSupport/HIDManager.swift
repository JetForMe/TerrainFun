//
//  HIDManager.swift
//  Wahangu
//
//  Created by Rick Mann on 2021-01-05.
//

import Foundation
import IOKit
import IOKit.hid


protocol
HIDManagerDelegate : AnyObject
{
	func deviceValueReceived(device inDevice: HIDDevice, element inElement: IOHIDElement, cookie inCookie: IOHIDElementCookie, code inCode: Int)
}

/**
	This is a very simplistic HIDManager wrapper that hard-codes device lookups,
	and makes a lot of assumptions (like there's only one particular device attached).
	
	Note: The USB entitlement must be enabled. If you get "IOServiceOpen failed: 0xe00002e2", try enabling that.
	
	What is "Error opening HIDDevice: 0xe00002c5, 709"?
	
*/

class
HIDManager
{
	static var shared = HIDManager()
	
	private
	init()
	{
		IOHIDManagerRegisterDeviceMatchingCallback(self.hm, self.attachCallback, Unmanaged<HIDManager>.passUnretained(self).toOpaque())
		IOHIDManagerRegisterDeviceRemovalCallback(self.hm, self.detachCallback, Unmanaged<HIDManager>.passUnretained(self).toOpaque())
		
		let devices = [
			kIOHIDDeviceUsagePageKey: 0x01,		//	Generic Desktop
			kIOHIDDeviceUsageKey: 0x08			//	Multi-axis Controller
		] as CFDictionary
		IOHIDManagerSetDeviceMatching(self.hm, devices)
		
		IOHIDManagerScheduleWithRunLoop(self.hm, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
		IOHIDManagerOpen(self.hm, IOOptionBits(kIOHIDOptionsTypeNone))
	}
	
	func
	attached(result: IOReturn, device inDevice: IOHIDDevice)
	{
		debugLog("attached: \(inDevice)")
		let device = HIDDevice(systemDevice: inDevice, delegate: self)
		self.devices.append(device)
	}
	
	func
	detached(result: IOReturn, device inDevice: IOHIDDevice)
	{
		debugLog("detached: \(inDevice)")
	}
	
	let			hm						=	IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
	var			devices					=	[HIDDevice]()
	weak var	delegate			:	HIDManagerDelegate?
	
	var			attachCallback		:	IOHIDDeviceCallback		=	{ (inCTX, inResult, inSender, inDevice) in
																		let this = Unmanaged<HIDManager>.fromOpaque(inCTX!).takeUnretainedValue()
																		this.attached(result: inResult, device: inDevice)
																	}
	var			detachCallback		:	IOHIDDeviceCallback		=	{ (inCTX, inResult, inSender, inDevice) in
																		let this = Unmanaged<HIDManager>.fromOpaque(inCTX!).takeUnretainedValue()
																		this.detached(result: inResult, device: inDevice)
																	}
}

extension
HIDManager : HIDDeviceDelegate
{
	func
	valueReceived(device inDevice: HIDDevice, element inElement: IOHIDElement, cookie inCookie: IOHIDElementCookie, code inCode: Int)
	{
		self.delegate?.deviceValueReceived(device: inDevice, element: inElement, cookie: inCookie, code: inCode)
	}
	
}

class
HIDDevice
{
	init(systemDevice inDevice: IOHIDDevice, delegate inDelegate: HIDDeviceDelegate? = nil)
	{
		self.device = inDevice
		self.delegate = inDelegate
		
		let result = IOHIDDeviceOpen(self.device, IOOptionBits(kIOHIDOptionsTypeNone))
		if result != kIOReturnSuccess
		{
			debugLog("Error opening HIDDevice: \(String(format: "0x%08x, %d", result, result & 0x3fff))")
		}
		
		IOHIDDeviceRegisterInputValueCallback(self.device, valueCallback, Unmanaged<HIDDevice>.passUnretained(self).toOpaque())
		if let ps = IOHIDDeviceGetProperty(self.device, "Product" as CFString) as? String
		{
			debugLog("Product: \(ps)")
		}

	}
	
	func
	valueReceived(result inResult: IOReturn, value inValue: IOHIDValue)
	{
		let element = IOHIDValueGetElement(inValue)
		let cookie = IOHIDElementGetCookie(element)
		let code = IOHIDValueGetIntegerValue(inValue)
		self.delegate?.valueReceived(device: self, element: element, cookie: cookie, code: code)
	}
	
	func
	getString(forProperty inKey: String)
		-> String?
	{
		return IOHIDDeviceGetProperty(self.device, inKey as CFString) as? String
	}
	
	func
	getInt(forProperty inKey: String)
		-> Int?
	{
		return IOHIDDeviceGetProperty(self.device, inKey as CFString) as? Int
	}
	
	var			device			:	IOHIDDevice
	weak var	delegate		:	HIDDeviceDelegate?
	
	var			valueCallback	:	IOHIDValueCallback		=	{ (inCTX, inResult, inSender, inValue) in
																	let this = Unmanaged<HIDDevice>.fromOpaque(inCTX!).takeUnretainedValue()
																	this.valueReceived(result: inResult, value: inValue)
																}
	lazy var			manufacturer	:	String?			=	self.getString(forProperty: kIOHIDManufacturerKey)
	lazy var			product			:	String?			=	self.getString(forProperty: kIOHIDProductKey)
}

protocol
HIDDeviceDelegate : AnyObject
{
	func		valueReceived(device inDevice: HIDDevice, element inElement: IOHIDElement, cookie inCookie: IOHIDElementCookie, code inCode: Int)
}
