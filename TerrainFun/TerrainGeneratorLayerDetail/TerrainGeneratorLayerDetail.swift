//
//	TerrainGeneratorLayerDetail.swift
//	TerrainFun
//
//	Created by Rick Mann on 2021-04-26.
//	Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import SwiftUI

struct TerrainGeneratorLayerDetail: View {
	let		layer					:	TerrainGeneratorLayer
	
	var body: some View {
		PerlinTerrainGeneratorView(layer: self.layer)
	}
}

struct TerrainGeneratorLayerDetail_Previews: PreviewProvider {
	static var previews: some View {
		TerrainGeneratorLayerDetail(layer: TerrainGeneratorLayer())
	}
}
