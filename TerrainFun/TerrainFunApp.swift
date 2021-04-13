//
//	TerrainFunApp.swift
//	TerrainFun
//
//	Created by Rick Mann on 2021-04-11.
//

import SwiftUI

@main
struct
TerrainFunApp: App
{
	var
	body: some Scene
	{
		DocumentGroup(newDocument: ProjectDocument())
		{ inFile in
			ProjectWindowContentView(document: inFile.$document)
		}
	}
}
