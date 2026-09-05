import SwiftUI

struct LearnView: View {
    @Environment(CameraRepository.self) private var repository
    @State private var showSharingNetwork = false
    private let articles: [LearnArticle] = LearnArticle.all

    private var cityRankings: [CityRanking] {
        GeoHelpers.cityRankings(from: repository.cameras, limit: 8)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        OverwatchPageHeader(
                            eyebrow: "OVERWATCH · INTEL",
                            title: "Learn",
                            subtitle: "Short, sharp context on ALPRs, networks, and why maps matter."
                        )

                        if !cityRankings.isEmpty {
                            SectionCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("MOST MAPPED METROS")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(0.8)
                                        .foregroundStyle(AppTheme.accent)
                                    Text("From mapped pins already on your device — incomplete coverage is curiosity, not a blank map.")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.mutedForeground)

                                    ForEach(Array(cityRankings.enumerated()), id: \.element.id) { index, city in
                                        HStack {
                                            Text("#\(index + 1)")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(AppTheme.primary)
                                                .frame(width: 28, alignment: .leading)
                                            Text(city.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(AppTheme.foreground)
                                            Spacer()
                                            Text(city.subtitle)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(AppTheme.mutedForeground)
                                        }
                                    }
                                }
                            }
                        }

                        ForEach(articles) { article in
                            SectionCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(article.eyebrow.uppercased())
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(0.8)
                                        .foregroundStyle(AppTheme.accent)
                                    Text(article.title)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(AppTheme.foreground)
                                    Text(article.body)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(AppTheme.mutedForeground)
                                        .fixedSize(horizontal: false, vertical: true)

                                    if article.id == LearnArticle.sharingNetworkArticleID {
                                        OverwatchPrimaryButton {
                                            showSharingNetwork = true
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: "point.3.connected.trianglepath.dotted")
                                                Text("Open sharing network map")
                                                    .fontWeight(.semibold)
                                            }
                                            .font(.system(size: 14))
                                        }
                                        .padding(.top, 4)
                                        .accessibilityHint("Shows FOIA-documented agency sharing links from DeFlock Dane")
                                    }
                                }
                            }
                        }

                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Public resources")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(AppTheme.foreground)

                                linkRow(
                                    title: "EFF on Flock Safety",
                                    url: URL(string: "https://www.eff.org/deeplinks/2025/12/effs-investigations-expose-flock-safetys-surveillance-abuses-2025-review")!
                                )
                                linkRow(
                                    title: "OpenStreetMap ALPR tagging",
                                    url: URL(string: "https://wiki.openstreetmap.org/wiki/Tag:surveillance:type=ALPR")!
                                )
                                linkRow(
                                    title: "DeFlock project",
                                    url: AppLinks.deFlockProject
                                )
                                linkRow(
                                    title: "DeFlock Dane shared networks",
                                    url: URL(string: "https://deflockdane.org/shared-networks/")!
                                )
                                linkRow(
                                    title: "Tennessee Code § 55-10-302",
                                    url: URL(string: "https://law.justia.com/codes/tennessee/title-55/chapter-10/part-3/section-55-10-302/")!
                                )
                                linkRow(
                                    title: "Memphis City Council minutes — June 24, 2025",
                                    url: URL(string: "https://memphistn.gov/wp-content/uploads/2025/07/Minutes-06-24-2025-1.pdf")!
                                )
                                linkRow(
                                    title: "Memphis Q1 FY26 finance (Insight / Flock-Falcon)",
                                    url: URL(string: "https://memphistn.gov/wp-content/uploads/2025/11/Q1-FINANCIAL-PRESENTAION_11.17.25-for-Council.pdf")!
                                )
                            }
                        }

                        Text("This app uses crowdsourced OpenStreetMap data, including cameras documented by the DeFlock community. Safest-drive scoring uses MapKit against that map. Sharing Network uses a public FOIA snapshot from DeFlock Dane — not live vendor data. Sensor Atlas overlays municipal traffic CCTV from public WisDOT inventory (not ALPR). GATES reconstructs Olive Branch city-limit crossings from the public record — not official Utility locations. It is not affiliated with Flock Safety.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                            .padding(.bottom, 12)
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showSharingNetwork) {
                SharingNetworkView()
            }
        }
    }

    private func linkRow(title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.foreground)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.vertical, 4)
        }
    }
}

private struct LearnArticle: Identifiable {
    let id: String
    let eyebrow: String
    let title: String
    let body: String

    static let sharingNetworkArticleID = "sharing-network"

    static let all: [LearnArticle] = [
        LearnArticle(
            id: "more-than-plate",
            eyebrow: "What ALPRs capture",
            title: "More than a plate",
            body: "Automated license plate readers photograph vehicles as they pass. Systems often store plate text, timestamp, location, and vehicle attributes such as color, make, and accessories. That creates a searchable trail of where cars have been."
        ),
        LearnArticle(
            id: "networks",
            eyebrow: "Networks",
            title: "Why sharing changes everything",
            body: "A single camera is a local sensor. A networked database lets agencies search across cities and states. The civic question is not only whether a camera exists, but who can query the history it feeds."
        ),
        LearnArticle(
            id: sharingNetworkArticleID,
            eyebrow: "FOIA sharing",
            title: "See who they share with",
            body: "Public records from three Wisconsin hubs (Waunakee, Middleton, Grand Chute) list thousands of partner agencies. Sharing Network maps those FOIA links by inferred county from the agency name — tap a state, then a county, for every listed agency. Pins are Census place/county matches, not FOIA addresses. Agency-to-agency relationships only, not which cameras feed which agency, and not a complete national graph. Snapshot attributed to DeFlock Dane; no Flock vendor APIs."
        ),
        LearnArticle(
            id: "retention",
            eyebrow: "Retention",
            title: "Tennessee keeps government plates 90 days",
            body: "Tennessee Code Annotated § 55-10-302 limits government ALPR captured-plate data to 90 days unless it is part of an ongoing investigation — then destroy it when that investigation or criminal action ends. The statute took effect in 2014. Its text covers governmental entities, not private owners. Atlas of Surveillance lists Shelby County Sheriff’s Office retention at 30 days. This app does not store plate reads."
        ),
        LearnArticle(
            id: "memphis-shelby",
            eyebrow: "Memphis / Shelby",
            title: "Council support is not a census",
            body: "On June 24, 2025, Memphis City Council approved a resolution supporting MPD license-plate readers on state highway rights-of-way. Those minutes name no dollar amount, camera count, or vendor. City of Memphis Q1 FY26 finance lists $318,000 paid to Insight Public Sector as “FLOCK-FALCON INFRASTRUCTURE-FREE,” coverage June 9, 2025–June 8, 2026. That is a vendor line, not a published MPD Flock census. This app does not invent one."
        ),
        LearnArticle(
            id: "this-map",
            eyebrow: "This map",
            title: "Community infrastructure",
            body: "Flock Surveillance plots ALPR nodes that volunteers have tagged in OpenStreetMap. Coverage is uneven by design: it reflects what people have documented, not a vendor’s private inventory. The radar shows fetch confidence (share of pins with a tagged OSM direction, and freshness), and soft-clears pins after a successful refresh no longer returns them. AR Camera Sight shows those same mapped locations in the street — not a live feed from any camera network."
        ),
        LearnArticle(
            id: "sensor-atlas",
            eyebrow: "Sensor Atlas",
            title: "Traffic cams are not ALPRs",
            body: "Toggle Traffic cams on the map to see municipal WisDOT traffic CCTV locations (Madison and Milwaukee snapshot). Opening a pin may load a traveler still from WisDOT hosts only — your device contacts that host; the app does not collect the image. These are not license-plate readers, not Flock Safety cameras, not live ALPR feeds, and they never feed proximity alerts. Proximity alerts only mean your phone is near a mapped OSM ALPR pin."
        ),
        LearnArticle(
            id: "olive-branch-gates",
            eyebrow: "Olive Branch",
            title: "Entranceways are a reconstruction",
            body: "August 2022: the city accepted Utility Associates for 24 ALPRs at unnamed “major entranceways.” May 7, 2024: the Board authorized terminating that Utility LPR agreement. December 17, 2024: consent item 16 approved Flock Group SaaS — minutes and agenda include no pin list or camera count. The mayor still described a 24-camera perimeter in 2026, including in county coverage framed as Flock. Atlas of Surveillance still lists Olive Branch ALPR as Coreforce / Utility 2022; that row is stale. Neighboring Southaven is listed by Atlas as 25 Flock as of September 2025. Horn Lake has had Flock since at least 2020; Atlas mis-files that agency as Tennessee. GATES plots a geographic reconstruction of those city-limit crossings against crowdsourced OSM pins (ODbL). A pin at a gate is not a confirmed 2022 Utility camera — Utility ≠ Flock — and a gap is not evidence the city skipped that road. The OSM city limit is TIGER 2008; annexation can shift a “city line.” These sites never feed proximity alerts."
        ),
        LearnArticle(
            id: "reporting",
            eyebrow: "Reporting",
            title: "How camera reports work",
            body: "Tap the flag on the map to report an unmapped camera, or flag a mapped one that changed. Your report is posted as an anonymous public note on OpenStreetMap and tracked on this device. We refresh nearby Overpass data and update the pending pin when mappers tag it — usually within days — then notify you when it lands."
        )
    ]
}
