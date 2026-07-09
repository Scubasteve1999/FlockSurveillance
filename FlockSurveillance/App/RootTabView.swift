import SwiftUI

struct RootTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            MapRadarView()
                .tabItem {
                    Label("Map", systemImage: "dot.radiowaves.left.and.right")
                }
                .tag(0)

            RouteExposureView()
                .tabItem {
                    Label("Route", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
                .tag(1)

            LearnView()
                .tabItem {
                    Label("Learn", systemImage: "book.closed.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(AppTheme.primary)
        .toolbarBackground(AppTheme.card, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
