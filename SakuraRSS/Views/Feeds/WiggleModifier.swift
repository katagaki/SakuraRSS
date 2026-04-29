import SwiftUI

struct WiggleModifier: ViewModifier {

    let isActive: Bool
    let seed: Double
    @State private var animate = false

    private var magnitude: Double {
        let normalized = abs(seed.truncatingRemainder(dividingBy: 1.0))
        return 1.6 + normalized * 0.8
    }

    private var duration: Double {
        let normalized = abs(seed.truncatingRemainder(dividingBy: 1.0))
        return 0.12 + normalized * 0.04
    }

    private var phaseOffset: Double {
        abs(seed.truncatingRemainder(dividingBy: 1.0)) * 0.08
    }

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + phaseOffset) {
                        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                            animate = true
                        }
                    }
                } else {
                    withAnimation(.default) {
                        animate = false
                    }
                }
            }
            .onAppear {
                guard isActive else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + phaseOffset) {
                    withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                        animate = true
                    }
                }
            }
    }

    private var rotation: Double {
        guard isActive else { return 0 }
        return animate ? magnitude : -magnitude
    }
}

extension View {
    func wiggle(_ isActive: Bool, seed: Double = 0) -> some View {
        modifier(WiggleModifier(isActive: isActive, seed: seed))
    }
}
