import SwiftUI

struct LearnView: View {
    @Environment(CameraRepository.self) private var repository
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
                        VStack(alignment: .leading, spacing: 6) {
                            Text("FLOCK SURVEILLANCE")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(AppTheme.primary)
                            Text("Learn")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.foreground)
                            Text("Short, sharp context on ALPRs, networks, and why maps matter.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.mutedForeground)
                        }

                        if !cityRankings.isEmpty {
                            SectionCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("MOST MAPPED METROS")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(0.8)
                                        .foregroundStyle(AppTheme.accent)
                                    Text("From cameras already on your device — incomplete coverage is curiosity, not a blank map.")
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
                            }
                        }

                        Text("This app uses crowdsourced OpenStreetMap data, including cameras documented by the DeFlock community. Safest-drive scoring uses MapKit against that map. It is not affiliated with Flock Safety.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                            .padding(.bottom, 12)
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
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

struct LearnArticle: Identifiable {
    let id = UUID()
    let eyebrow: String
    let title: String
    let body: String

    static let all: [LearnArticle] = [
        LearnArticle(
            eyebrow: "What ALPRs capture",
            title: "More than a plate",
            body: "Automated license plate readers photograph vehicles as they pass. Systems often store plate text, timestamp, location, and vehicle attributes such as color, make, and accessories. That creates a searchable trail of where cars have been."
        ),
        LearnArticle(
            eyebrow: "Networks",
            title: "Why sharing changes everything",
            body: "A single camera is a local sensor. A networked database lets agencies search across cities and states. The civic question is not only whether a camera exists, but who can query the history it feeds."
        ),
        LearnArticle(
            eyebrow: "Retention",
            title: "Time is a policy choice",
            body: "How long plate reads are kept varies by contract and jurisdiction. Shorter retention limits retrospective tracking; longer retention expands it. Transparency about retention is part of democratic oversight."
        ),
        LearnArticle(
            eyebrow: "This map",
            title: "Community infrastructure",
            body: "Flock Surveillance plots ALPR nodes that volunteers have tagged in OpenStreetMap. Coverage is uneven by design: it reflects what people have documented, not a vendor’s private inventory."
        ),
        LearnArticle(
            eyebrow: "Reporting",
            title: "How camera reports work",
            body: "Tap the flag on the map to report an unmapped camera, or flag a mapped one that changed. Your report is posted as an anonymous public note on OpenStreetMap. Volunteer mappers verify it on the ground, tag it with surveillance:type=ALPR, and it then appears here and in DeFlock — usually within days."
        )
    ]
}
