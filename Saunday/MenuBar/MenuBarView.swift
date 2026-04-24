import SwiftUI

struct MenuBarView: View {
    @Environment(VisualizerViewModel.self) var viewModel

    private let barCount = 20

    var body: some View {
        HStack(spacing: 6) {
            if let img = viewModel.artwork {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .id(img)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    let mag = interpolated(bar: i, total: barCount)
                    Capsule()
                        .fill(.white)
                        .frame(width: 1.5, height: max(2, 14 * CGFloat(mag)))
                        .transaction { $0.animation = .linear(duration: 0.08) }
                }
            }
            .frame(height: 18)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.8))
        .clipShape(Capsule())
        .fixedSize()
    }

    private func interpolated(bar i: Int, total: Int) -> Float {
        let bands = viewModel.barMagnitudes
        let n = bands.count
        guard n > 0, total > 0 else { return 0 }
        let pos = Float(i) / Float(total) * Float(n - 1)
        let lo  = Int(pos)
        let hi  = min(lo + 1, n - 1)
        let t   = pos - Float(lo)
        return bands[lo] * (1 - t) + bands[hi] * t
    }
}
