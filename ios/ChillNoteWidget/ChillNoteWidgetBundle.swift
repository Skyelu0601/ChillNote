//
//  ChillScriptWidgetBundle.swift
//  ChillScriptWidget
//
//  Created by 陆文婷 on 2026/1/22.
//

import WidgetKit
import SwiftUI

@main
struct ChillScriptWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        ChillScriptWidget()
        if #available(iOSApplicationExtension 18.0, *) {
            ChillScriptWidgetControl()
        }
    }
}
