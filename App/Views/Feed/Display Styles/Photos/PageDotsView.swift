import SwiftUI

struct PageDotsView: View {

    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.white : Color.white.opacity(0.5))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.3), in: .capsule)
        .animation(.easeInOut(duration: 0.2), value: current)
    }
}
