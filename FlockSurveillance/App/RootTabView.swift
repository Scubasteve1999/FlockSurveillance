import SwiftUI

struct RootTabView: View {
    @Binding var selectedTab: Int
    /// Latches true on first visit so the Map (and its camera/state) survives tab switches.
    @State private var mapMounted = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Mount MapKit lazily on first visit — eager TabView construction of
            // Map + Route maps freezes the first frame on iPad — then keep it mounted
            // so returning to the tab doesn't rebuild the map or reset the camera.
            Group {
                if selectedTab == 0 || mapMounted {
                    MapRadarView()
                } else {
                    AppTheme.background.ignoresSafeArea()
                }
            }
            .tabItem {
                Label("MAP", systemImage: "map.fill")
            }
            .tag(0)
            .onAppear { if selectedTab == 0 { mapMounted = true } }
            .onChange(of: selectedTab) { _, tab in if tab == 0 { mapMounted = true } }

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
