//
//  DEMLayerDetailsView.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-26.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import SwiftUI

import Foundation





struct
DEMLayerDetail: View
{
						let		layer					:	Layer
	@Binding			var		local					:	CGPoint		//	TODO: I don't really like this binding shit here, but tracking is super broken anyway. I think we can handle tracking outside of these detail views
	@Binding			var		cursorPosition			:	CGPoint
						
	var body: some View {
		//				ScrollView {
		
		//	Get the image scaled for our current image size…
		
		GeometryReader { geo in
			let image: Image = {
			if let wi = self.layer.workingImage
			{
				return  Image(nsImage: NSImage(cgImage: wi, size: .zero))
			}
			else
			{
				return Image("questionmark.square.dashed")
			}}()
			
			image
				.resizable()
				.border(Color.red)
				.aspectRatio(contentMode: .fit)
				.trackingMouse(onMove: { inPoint in
					self.local = inPoint
					let scale = self.layer.sourceSize! / geo.size
					self.cursorPosition = scale * inPoint
				})
				.highPriorityGesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
									.onChanged { _ in
//					                    debugLog("loc: \($0.location)")
									})
			//				}
		}
	}
}

