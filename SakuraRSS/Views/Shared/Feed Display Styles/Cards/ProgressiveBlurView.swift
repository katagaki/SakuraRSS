import SwiftUI

/// Progressive blur fading from sharp top to heavily blurred bottom.
struct ProgressiveBlurView: UIViewRepresentable {

    @Environment(\.colorScheme) private var colorScheme

    func makeUIView(context _: Context) -> ProgressiveBlurUIView {
        ProgressiveBlurUIView(blurStyle: blurStyle)
    }

    func updateUIView(_ view: ProgressiveBlurUIView, context _: Context) {
        view.update(blurStyle: blurStyle)
    }

    private var blurStyle: UIBlurEffect.Style {
        colorScheme == .dark ? .dark : .light
    }
}

final class ProgressiveBlurUIView: UIView {

    static let steps = 6
    private var blurStyle: UIBlurEffect.Style
    private let tintOverlay = UIView()

    init(blurStyle: UIBlurEffect.Style) {
        self.blurStyle = blurStyle
        super.init(frame: .zero)
        clipsToBounds = true

        for _ in 0..<Self.steps {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(blur)
        }

        tintOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(tintOverlay)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    func update(blurStyle style: UIBlurEffect.Style) {
        blurStyle = style
        for case let blur as UIVisualEffectView in subviews {
            blur.effect = UIBlurEffect(style: style)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let blurViews = subviews.compactMap { $0 as? UIVisualEffectView }
        guard blurViews.count == Self.steps else { return }

        for (index, blur) in blurViews.enumerated() {
            blur.frame = bounds

            let mask = CAGradientLayer()
            mask.frame = bounds
            mask.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor,
                           UIColor.black.cgColor, UIColor.black.cgColor]

            let start = CGFloat(index) / CGFloat(Self.steps)
            let end = CGFloat(index + 1) / CGFloat(Self.steps)
            mask.locations = [0, NSNumber(value: start), NSNumber(value: end), 1]
            mask.startPoint = CGPoint(x: 0.5, y: 0)
            mask.endPoint = CGPoint(x: 0.5, y: 1)
            blur.layer.mask = mask

            blur.alpha = CGFloat(index + 1) / CGFloat(Self.steps)
        }

        tintOverlay.frame = bounds
        tintOverlay.backgroundColor = blurStyle == .dark
            ? UIColor.black.withAlphaComponent(0.3)
            : UIColor.white.withAlphaComponent(0.3)

        let tintMask = CAGradientLayer()
        tintMask.frame = bounds
        tintMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        tintMask.startPoint = CGPoint(x: 0.5, y: 0)
        tintMask.endPoint = CGPoint(x: 0.5, y: 1)
        tintOverlay.layer.mask = tintMask
    }
}
