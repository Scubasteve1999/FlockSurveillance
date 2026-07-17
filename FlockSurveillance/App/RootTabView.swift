import SwiftUI

struct RootTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            // Only mount MapKit when the Map tab is selected — eager TabView
            // construction of Map + Route maps freezes the first frame on iPad.
            Group {
                if selectedTab == 0 {
                    MapRadarView()
                } else {
                    AppTheme.background.ignoresSafeArea()
                }
            }
            .tabItem {
                Label("MAP", systemImage: "dot.radiowaves.left.and.right")
            }
            .tag(0)

            Group {
                if selectedTab == 1 {
                    RouteExposureView()
                } else {
                    AppTheme.background.ignoresSafeArea()
                }
            }
            .tabItem {
                Label("ROUTE", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            }
            .tag(1)

            LearnView()
                .tabItem {
                    Label("INTEL", systemImage: "book.closed.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("GEAR", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(AppTheme.primary)
        .toolbarBackground(AppTheme.card, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
