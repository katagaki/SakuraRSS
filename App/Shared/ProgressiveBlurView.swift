import SwiftUI
import Hanami

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
    private let tintMask = CAGradientLayer()

    init(blurStyle: UIBlurEffect.Style) {
        self.blurStyle = blurStyle
        super.init(frame: .zero)
        clipsToBounds = true

        for index in 0..<Self.steps {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blur.alpha = CGFloat(index + 1) / CGFloat(Self.steps)
            blur.layer.mask = Self.makeStepMask(index: index)
            addSubview(blur)
        }

        tintMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        tintMask.startPoint = CGPoint(x: 0.5, y: 0)
        tintMask.endPoint = CGPoint(x: 0.5, y: 1)
        tintOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tintOverlay.layer.mask = tintMask
        addSubview(tintOverlay)
        applyTintColor()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    func update(blurStyle style: UIBlurEffect.Style) {
        guard style != blurStyle else { return }
        blurStyle = style
        for case let blur as UIVisualEffectView in subviews {
            blur.effect = UIBlurEffect(style: style)
        }
        applyTintColor()
    }

    // Masks are created once; layout only moves frames, because this view is
    // resized every frame of the expand animation in the Scroll style.
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for subview in subviews {
            subview.frame = bounds
            subview.layer.mask?.frame = bounds
        }
        CATransaction.commit()
    }

    private func applyTintColor() {
        tintOverlay.backgroundColor = blurStyle == .dark
            ? UIColor.black.withAlphaComponent(0.3)
            : UIColor.white.withAlphaComponent(0.3)
    }

    private static func makeStepMask(index: Int) -> CAGradientLayer {
        let mask = CAGradientLayer()
        mask.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor,
                       UIColor.black.cgColor, UIColor.black.cgColor]
        let start = CGFloat(index) / CGFloat(steps)
        let end = CGFloat(index + 1) / CGFloat(steps)
        mask.locations = [0, NSNumber(value: start), NSNumber(value: end), 1]
        mask.startPoint = CGPoint(x: 0.5, y: 0)
        mask.endPoint = CGPoint(x: 0.5, y: 1)
        return mask
    }
}
