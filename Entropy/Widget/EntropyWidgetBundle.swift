import WidgetKit
import SwiftUI

// NOTE: This file belongs in a separate Widget Extension target in Xcode.
// Do NOT include it in the main app target — it has its own @main entry point.
// In Xcode: File → New → Target → Widget Extension → "EntropyWidgets"
@main
struct EntropyWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickCaptureWidget()
        UpcomingTripsWidget()
        RemindersWidget()
    }
}
