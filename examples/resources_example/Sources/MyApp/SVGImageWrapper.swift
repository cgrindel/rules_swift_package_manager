import PocketSVG
import SwiftUI
import UIKit

struct SVGImageWrapper: UIViewRepresentable {
    var resource: String

    func makeUIView(context _: Context) -> SVGImageView {
        let url = Bundle.module.url(forResource: resource, withExtension: "svg")!
        let svgImageView = SVGImageView(contentsOf: url)
        svgImageView.contentMode = .scaleAspectFit
        return svgImageView
    }

    func updateUIView(_: SVGImageView, context _: Context) {}

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView _: SVGImageView,
        context _: Context
    ) -> CGSize? {
        guard
            let width = proposal.width,
            let height = proposal.height
        else { return nil }

        return CGSize(width: width, height: height)
    }
}
