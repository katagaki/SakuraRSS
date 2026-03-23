import SwiftUI

struct ZoomableImageModifier: ViewModifier {

    @State private var scale: CGFloat = 1.0
    @State private var anchor: UnitPoint = .center
    @State private var isZooming = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: anchor)
            .zIndex(isZooming ? 1 : 0)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        isZooming = true
                        let newScale = max(value.magnification, 1.0)
                        scale = newScale
                        anchor = value.startAnchor
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            scale = 1.0
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
