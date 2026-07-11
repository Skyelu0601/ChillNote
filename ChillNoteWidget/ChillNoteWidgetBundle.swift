//
//  ChillNoteWidgetBundle.swift
//  ChillNoteWidget
//
//  Created by 陆文婷 on 2026/1/22.
//

import WidgetKit
import SwiftUI

@main
struct ChillNoteWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        ChillNoteWidget()
        if #available(iOSApplicationExtension 18.0, *) {
            ChillNoteWidgetControl()
        }
    }
}
