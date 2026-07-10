import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(AppTheme.accent)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct SafariPresentation: Identifiable {
    let id = UUID()
    let url: URL
}

extension View {
    func safariSheet(item: Binding<SafariPresentation?>) -> some View {
        sheet(item: item) { presentation in
            SafariView(url: presentation.url)
                .ignoresSafeArea()
        }
    }
}
