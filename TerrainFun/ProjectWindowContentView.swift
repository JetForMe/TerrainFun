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
			List([DEMLayer()]) { layer in
				NavigationLink(destination: LayerDetail(layer: layer)) {
					LayerItemCell()
				}
			}
			.frame(minWidth: 200.0)
			.border(Color.blue, width: self.dropTargeted ? 2 : 0)
		}
		.navigationViewStyle(DoubleColumnNavigationViewStyle())
		.onDrop(of: [.fileURL], isTargeted: self.$dropTargeted, perform: { inProviders in
			guard let p = inProviders.first else { return false }
			
			p.loadObject(ofClass: URL.self) { inURL, inError in
				guard
					let url = inURL
				else
				{
					debugLog("Error: \(inError)")
					return
				}
				
				debugLog("URL: \(url.path)")
			}
			debugLog("drop: \(p)")
			return true
		})
    }
    
    var shouldDisplayHover: Bool		=	false
}

struct
LayerDetail: View
{
						let		layer					:	Layer
	@State		private	var		cursorPosition			:	CGPoint			=	.zero
	
	var body: some View {
		VStack {
			Spacer()
			
			//				ScrollView {
			Image("dev-image")
				.resizable()
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
			LayerInfoBar(cursorPosition: self.cursorPosition)
		}
		.background(Color("layer-background"))
		.frame(minWidth: 100.0, idealWidth: 1600.0, minHeight: 100.0, idealHeight: 800.0)		//	TODO: Make default size relative to screen size
	}
}

struct
LayerItemCell: View
{
	var body: some View {
		HStack {
			Text("Mars MOLA DEMasdf df asd fsdf")
				.lineLimit(1)
				.font(.headline)
			Spacer()
			Image(systemName: "eye")
		}
	}
}

struct LayerInfoBar: View {
	let		cursorPosition			:	CGPoint
	
	var body: some View {
		HStack
		{
			Text("X: \(self.cursorPosition.x, specifier: "%0.f")")
				.frame(minWidth: 100, alignment: .leading)
			Text("Y: \(self.cursorPosition.y, specifier: "%0.f")")
				.frame(minWidth: 100, alignment: .leading)
			Text("Lat: \(37.12345, specifier: "%0.4f")")
				.frame(minWidth: 100, alignment: .leading)
			Text("Lon: \(-113.54321, specifier: "%0.4f")")
				.frame(minWidth: 100, alignment: .leading)
			Spacer()
		}
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

