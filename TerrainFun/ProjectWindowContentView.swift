//
//  ProjectWindowContentView.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-11.
//

import SwiftUI

import UniformTypeIdentifiers

/**
	Might be a hint as to how to preview. This is for video, but it shows
	using a Metal view in SwiftUI, and that's attached to a CIImage:
	
		https://github.com/frankschlegel/core-image-by-example/blob/main/Shared/PreviewView.swift
		
*/

struct
ProjectWindowContentView: View
{
    @ObservedObject		var		document				:	ProjectDocument
	@State				var		dropTargeted			:	Bool = false
						
    var body: some View
    {
		NavigationView {
			List(self.document.layers) { inLayer in
				NavigationLink(destination: LayerDetail(layer: inLayer)) {
					LayerItemCell(layer: inLayer)
				}
			}
			.frame(minWidth: 200.0)
			.border(Color.blue, width: self.dropTargeted ? 2 : 0)
		}
		.navigationViewStyle(DoubleColumnNavigationViewStyle())
		.onDrop(of: [.fileURL], isTargeted: self.$dropTargeted, perform: { inProviders in
			guard let p = inProviders.first else { return false }
			
			_ = p.loadObject(ofClass: URL.self) { inURL, inError in
				guard
					let url = inURL
				else
				{
					debugLog("Error: \(String(describing: inError))")
					return
				}
				
				debugLog("URL: \(url.path)")
				self.document.importFile(url: url)
			}
			debugLog("drop: \(p)")
			return true
		})
    }
    
    var shouldDisplayHover: Bool		=	false
}

struct
LayerItemCell: View
{
	let			layer:		Layer
	
	var body: some View {
		let s = HStack {
			Text(self.layer.name ?? "New Layer")		//	TODO: What do we do if the layer has no name?
				.lineLimit(1)
				.font(.headline)
			Spacer()
			Image(systemName: "eye")
		}
		if let url = self.layer.url
		{
			s.help(url.path)
		}
		else
		{
			s
		}
	}
}


struct
LayerDetail: View
{
						let		layer					:	Layer
	@State		private	var		cursorPosition			:	CGPoint			=	.zero
	@State		private	var		imageScale				:	CGPoint			=	CGPoint(x: 1.0, y: 1.0)
	
	var body: some View {
		VStack {
			Spacer()
			
			//				ScrollView {
			
			//	Get the image scaled for our current image size…
			
			let image: Image = {
			if let wi = self.layer.workingImage
			{
				return  Image(nsImage: NSImage(cgImage: wi, size: .zero))
			}
			else
			{
				return Image("questionmark.square.dashed")
			}}()
			
			image.resizable()
				.trackingMouse { inPoint in
					self.cursorPosition = inPoint
				}
				.aspectRatio(contentMode: .fit)
				.highPriorityGesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
									.onChanged { _ in
//					                    debugLog("loc: \($0.location)")
									})
			//				}
			Spacer()
			let g = self.layer.projection!.geodetic(from: self.cursorPosition)
			LayerInfoBar(cursorPosition: self.cursorPosition, geodeticPosition: g)
		}
		.background(Color("layer-background"))
		.frame(minWidth: 100.0, idealWidth: 1600.0, minHeight: 100.0, idealHeight: 800.0)		//	TODO: Make default size relative to screen size
	}
}

struct LayerInfoBar: View {
	let		cursorPosition			:	CGPoint
	let		geodeticPosition		:	CLLocationCoordinate2D
	
	var body: some View {
		HStack
		{
			Text("X: \(self.cursorPosition.x, specifier: "%0.f")")
				.frame(minWidth: 100, alignment: .leading)
			Text("Y: \(self.cursorPosition.y, specifier: "%0.f")")
				.frame(minWidth: 100, alignment: .leading)
			Text("Lat: \(self.geodeticPosition.latitude, specifier: "%0.4f")")
				.frame(minWidth: 100, alignment: .leading)
			Text("Lon: \(self.geodeticPosition.longitude, specifier: "%0.4f")")
				.frame(minWidth: 100, alignment: .leading)
			Spacer()
		}
		.frame(minWidth: 0.0, alignment: .leading)
		.background(Color("status-bar-background"))
	}
}



struct
ProjectWindowContentView_Previews: PreviewProvider
{
    static
    var previews: some View
    {
		ProjectWindowContentView(document: ProjectDocument())
			
    }
}

