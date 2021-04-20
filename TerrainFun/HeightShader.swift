//
//  HeightShader.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-20.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import CoreImage

class
HeightShader: CIFilter
{
	public var inputImage			:	CIImage?
//	public var minimum
	override
	init()
	{
		
		super.init()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override var outputImage: CIImage?
	{
		get
		{
			guard let input = self.inputImage else { return nil }
			let cb: CIKernelROICallback =
			{ inIndex, inDestRect -> CGRect in
				return .null
			}
			return Self.kernel.apply(extent: input.extent, roiCallback: cb, arguments: [input])
		}
	}
	
	static
	var
	kernel: CIKernel =
		{ () -> CIKernel in
		let url = Bundle.main.url(forResource: "HeightShader", withExtension: "ci.metallib")!
		let data = try! Data(contentsOf: url)
		return try! CIKernel(functionName: "heightShader", fromMetalLibraryData: data, outputPixelFormat: .L16)
	}()
}
