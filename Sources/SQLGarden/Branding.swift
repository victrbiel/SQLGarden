import AppKit
import SwiftUI

/// Original artwork supplied with SQLGarden. Bundle icon remains the light
/// variant; only the running application's Dock icon follows its appearance.
@MainActor final class BrandIconView: NSView {
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); updateIcon() }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); updateIcon() }
    private func updateIcon() {
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        guard let url = Bundle.main.url(forResource: dark ? "AppIconDark" : "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: url) else { return }
        NSApplication.shared.applicationIconImage = image
    }
}
struct BrandAppearanceObserver: NSViewRepresentable {
    func makeNSView(context: Context) -> BrandIconView { BrandIconView() }
    func updateNSView(_ view: BrandIconView, context: Context) {}
}
struct SQLGardenLogo: View {
    var body: some View {
        Image("SQLGardenLogo")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .accessibilityLabel("SQLGarden — desenvolvido por Victor")
    }
}
