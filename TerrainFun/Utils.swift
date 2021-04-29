//
//  Utils.swift
//  SatTraX
//
//  Created by Roderick Mann on 2017-10-20.
//  Copyright © 2017 Latency: Zero, LLC. All rights reserved.
//


import CoreGraphics
import Foundation


extension Double
{
	public static var	twoPi: Double							{ return 2.0 * Double.pi }
	public static var	radToDeg: Double						{ return 180.0 / Double.pi }
	public static var	degToRad: Double						{ return Double.pi / 180.0 }
	public static var	minutesPerDay: Double					{ return 24.0 * 60.0 }
	public static var	daysPerMinute: Double					{ return 1.0 / Double.minutesPerDay }
	public static var	secondsPerMinute: Double				{ return 60.0 }
	public static var	secondsPerDay: Double					{ return minutesPerDay * secondsPerMinute }
	public static var	daysPerSecond: Double					{ return 1.0 / secondsPerDay }
	
	public static var	earthRadius: Double						{ return 6378.137 }
	public static var	earthEccentricitySquared: Double		{ return 0.006694385000 }
	
	public static var	epsilon: Double							{ return 0.00000001 }
	
	func
	signum()
		-> Double
	{
		if self < 0.0
		{
			return -1.0
		}
		else if self > 0.0
		{
			return 1.0
		}
		else
		{
			return 0.0
		}
	}
	
}


func
debugLog<T>(_ inMsg: T, file inFile : String = #file, line inLine : Int = #line)
{
	let file = (inFile as NSString).lastPathComponent
	let s = "\(file):\(inLine)    \(inMsg)"
	print(s)
}

func
debugLog(format inFormat: String, file inFile : String = #file, line inLine : Int = #line, _ inArgs: CVarArg...)
{
	let s = String(format: inFormat, arguments: inArgs)
	debugLog(s, file: inFile, line: inLine)
}



extension CGSize
{
	static
	func /(lhs: CGSize, rhs: CGSize)
		-> CGSize
	{
		return CGSize(width: lhs.width / rhs.width, height: lhs.height / rhs.height)
	}
	
	static
	func *(lhs: CGSize, rhs: CGPoint)
		-> CGPoint
	{
		return CGPoint(x: lhs.width * rhs.x, y: lhs.height * rhs.y)
	}
}

import SwiftUI

extension
DefaultStringInterpolation
{
	mutating
	func
	appendInterpolation<T>(_ inVal: T, specifier inSpecifier: String) where T : _FormatSpecifiable
	{
		appendInterpolation(String(format: inSpecifier, inVal as! CVarArg))
	}
}



