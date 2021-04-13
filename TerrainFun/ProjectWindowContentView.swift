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
		HSplitView {
			List() {
				Text("Mars MOLA DEM")
				Text("Contour")
				Text("3D Mesh")
			}
			.frame(idealWidth:200)
			Image("document-error")
				.resizable()
				.aspectRatio(contentMode: .fit)
		}
    }
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
