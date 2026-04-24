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
        .background {
            let palette = viewModel.meshPalette
            if palette.count >= 2 {
                AnimatedMeshBackground(palette: palette)
            } else {
                Color.black.opacity(0.8)
            }
        }
        .clipShape(Capsule())
        .fixedSize()
        .animation(.easeInOut(duration: 0.5), value: viewModel.meshPalette.count > 0)
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

private struct AnimatedMeshBackground: View {
    let palette: [Color]

    var body: some View {
        TimelineView(.animation) { context in
            let t = Float(context.date.timeIntervalSince1970)
            let ox  = sin(t * 0.8) * 0.15
            let oy  = cos(t * 0.6) * 0.15
            let ox2 = sin(t * 0.5 + 1.0) * 0.12
            let oy2 = cos(t * 0.7 + 0.5) * 0.12

            MeshGradient(
                width: 4,
                height: 4,
                points: [
                    [0.0, 0.0], [0.3, 0.0],              [0.7, 0.0],              [1.0, 0.0],
                    [0.0, 0.3], [0.2 + ox,  0.4 + oy],   [0.7 + ox,  0.2 + oy],  [1.0, 0.3],
                    [0.0, 0.7], [0.3 + ox2, 0.8 + oy2],  [0.7 + ox2, 0.6 + oy2], [1.0, 0.7],
                    [0.0, 1.0], [0.3, 1.0],              [0.7, 1.0],              [1.0, 1.0],
                ],
                colors: meshColors(palette: palette)
            )
            .blur(radius: 8)
        }
    }

    private func meshColors(palette: [Color]) -> [Color] {
        let c0 = palette[0]
        let c1 = palette.count > 1 ? palette[1] : palette[0]
        let c2 = palette.count > 2 ? palette[2] : palette[0]
        let c3 = palette.count > 3 ? palette[3] : c1

        return [
            c1,  c0,  c1,  c2,
            c0,  c2,  c3,  c1,
            c2,  c3,  c0,  c2,
            c3,  c1,  c2,  c0,
        ]
    }
}
