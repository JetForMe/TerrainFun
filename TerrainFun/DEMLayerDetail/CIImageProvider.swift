//
//  CIImageProvider.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-20.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import CoreImage



/**
	Because this is an informal protocol not defined in any Apple header,
	we’ll define it here for completeness (and a place to document it).
*/

@objc
protocol
CIImageProvider
{
	/**
		Comments taken from Objective-C header CoreImage/CIImageProvider.h:
		
		Callee should initialize the given bitmap with the subregion x,y
		width,height of the image. (this subregion is defined in the image's
		local coordinate space, i.e. the origin is the top left corner of
		the image).

		By default, this method will be called to requests the full image
		data regardless of what subregion is needed for the current render.
		All of the image is loaded or none of it is.

		If the `CIImage.providerTileSize` option is specified, then only the
		tiles that are needed are requested.

		Changing the virtual memory mapping of the supplied buffer (e.g. using
		vm_copy() to modify it) will give undefined behavior.
			
		- Parameters:
			- ioData: A pre-allocated buffer to contain the image data for the requested tile.
			- inRowbytes: Bytes per row of the supplied tile buffer.
			- inX: X-coordinate of the origin of the tile in image space.
			- inY: Y-coordinate of the origin of the tile in image space.
			- inWidth: Width of requested tile in image space.
			- inHeight: Height of requested tile in image space.
			- inInfo: Information supplied in CIImage constructor.
	*/
	
	@objc
	func
	provideImageData(_ ioData: UnsafeMutableRawPointer,
						bytesPerRow inRowbytes: Int,
						origin inX: Int,
								_ inY: Int,
						size inWidth: Int,
							_ inHeight: Int,
						userInfo inInfo: Any?)
}
