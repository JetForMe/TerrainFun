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
    @Binding var document: ProjectDocument

    var body: some View {
		NavigationView {
			List(0..<5) { layer in
				HStack {
					Text("Mars MOLA DEM")
						.font(.headline)
				}
				.frame(idealWidth:200)
			}
			
			VStack {
				Spacer()
				
//				ScrollView {
				GeometryReader { inGeometry  in
					Image("dev-image")
						.resizable()
						.aspectRatio(contentMode: .fit)
//						.onHover(perform: { hovering in		//	This never gets called
//							debugLog("hovering")
//						})
						.onAppear
						{
							NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { inEvent in
								let globalFrame = inGeometry.frame(in: .global)
								let p = inEvent.locationInWindow
								if globalFrame.contains(p)
								{
									debugLog("mouse moved: \(p.x), \(p.y)")
								}
								return nil
							}
						}
				}
//				}
				Spacer()
				HStack
				{
					Text("X: \(1.0, specifier: "%0.f")")
					Text("Y: \(1.0, specifier: "%0.f")")
					Text("Lat: \(37.12345, specifier: "%0.4f")")
					Text("Lon: \(-113.54321, specifier: "%0.4f")")
					Spacer()
				}
			}
		}
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
