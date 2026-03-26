import SwiftUI

struct ZoomableImageModifier: ViewModifier {

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var anchor: UnitPoint = .center
    @State private var isZooming = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: anchor)
            .offset(offset)
            .zIndex(isZooming ? 1 : 0)
            .gesture(
                MagnifyGesture()
                    .simultaneously(with: DragGesture())
                    .onChanged { value in
                        isZooming = true
                        if let magnification = value.first?.magnification {
                            scale = max(magnification, 1.0)
                        }
                        if let startAnchor = value.first?.startAnchor {
                            anchor = startAnchor
                        }
                        if let translation = value.second?.translation, scale > 1.0 {
                            offset = translation
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.smooth.speed(2.0)) {
                            scale = 1.0
                            offset = .zero
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isZooming = false
                        }
                    }
            )
    }
}

extension View {
    func zoomable() -> some View {
        modifier(ZoomableImageModifier())
    }
}
