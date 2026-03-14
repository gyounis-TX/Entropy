import WidgetKit
import SwiftUI

@main
struct EntropyWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickCaptureWidget()
        UpcomingTripsWidget()
        RemindersWidget()
    }
}
