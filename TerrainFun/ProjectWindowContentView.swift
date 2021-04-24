//
//  ProjectWindowContentView.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-11.
//

import SwiftUI

/**
	Might be a hint as to how to preview. This is for video, but it shows
	using a Metal view in SwiftUI, and that's attached to a CIImage:
	
		https://github.com/frankschlegel/core-image-by-example/blob/main/Shared/PreviewView.swift
		
*/

struct
ProjectWindowContentView: View
{
    @Binding			var		document				:	ProjectDocument
	@State				var		dropTargeted			:	Bool = false
						
    var body: some View {
		NavigationView {
			List(self.document.layers) { layer in
				NavigationLink(destination: LayerDetail()) {
					HStack {
						Text("Mars MOLA DEM")
							.font(.headline)
						Spacer()
						Image(systemName: "eye")
					}
				}
			}
			.frame(idealWidth:200)
		}
		.navigationViewStyle(DoubleColumnNavigationViewStyle())
		.onDrop(of: [.image], isTargeted: self.$dropTargeted, perform: { providers in
			debugLog("drop: \(providers)")
			return false
		})
    }
    
    var shouldDisplayHover: Bool		=	false
}

struct
ProjectWindowContentView_Previews: PreviewProvider
{
    static
    var previews: some View
    {
		ProjectWindowContentView(document: .constant(ProjectDocument()))
			
    }
}

struct LayerDetail: View {
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
			//				}
			Spacer()
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
		.background(Color("layer-background"))
	}
}
