//
//  VoucherWidgetLiveActivity.swift
//  VoucherWidget
//
//  Created by JEREMY on 09/04/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct VoucherWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct VoucherWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VoucherWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension VoucherWidgetAttributes {
    fileprivate static var preview: VoucherWidgetAttributes {
        VoucherWidgetAttributes(name: "World")
    }
}

extension VoucherWidgetAttributes.ContentState {
    fileprivate static var smiley: VoucherWidgetAttributes.ContentState {
        VoucherWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: VoucherWidgetAttributes.ContentState {
         VoucherWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: VoucherWidgetAttributes.preview) {
   VoucherWidgetLiveActivity()
} contentStates: {
    VoucherWidgetAttributes.ContentState.smiley
    VoucherWidgetAttributes.ContentState.starEyes
}
