//
//  Layer.swift
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-22.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

import Foundation
import SwiftUI



class
Layer : ObservableObject, Identifiable
{
				var			id						:	UUID			=	UUID()
	@Published	var			name					:	String?
	@Published	var			visible					:	Bool			=	true			//	TODO: Perhaps this should be a property of the view. But it should be persisted, and that could get messy.
}

class
DEMLayer : Layer
{
}
