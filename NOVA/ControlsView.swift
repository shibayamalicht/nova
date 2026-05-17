import SwiftUI
import AppKit

struct ControlsView: View {
    @EnvironmentObject var vm: PlayerViewModel
    @State private var isSeeking = false
    @State private var seekValue: Double = 0

    var body: some View {
        VStack(spacing: 18) {
            timeRow
            buttonRow
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                LinearGradient(
                    colors: [.white.opacity(0.06), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Theme.glassStroke, lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.55), radius: 22, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var timeRow: some View {
        HStack(spacing: 14) {
            Text(timeString(vm.currentTime))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 64, alignment: .trailing)

            GradientSlider(
                value: Binding(
                    get: { isSeeking ? seekValue : vm.currentTime },
                    set: { newValue in
                        isSeeking = true
                        seekValue = newValue
                    }
                ),
                range: 0...max(vm.duration, 1),
                onCommit: {
                    vm.seek(to: seekValue)
                    isSeeking = false
                }
            )
            .frame(height: 22)

            Text(timeString(vm.duration))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 64, alignment: .leading)
        }
    }

    private var buttonRow: some View {
        HStack(spacing: 16) {
            iconButton(systemName: "gobackward.10") { vm.skip(by: -10) }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .help("10秒戻る")

            playButton

            iconButton(systemName: "goforward.10") { vm.skip(by: 10) }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .help("10秒進む")

            volumeControl

            Spacer()

            iconButton(systemName: vm.isFloating ? "pip.fill" : "pip", isActive: vm.isFloating) {
                vm.isFloating.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .help("常に手前に表示 (PiP代替)")

            iconButton(systemName: "arrow.up.left.and.arrow.down.right") {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
            .help("フルスクリーン")
        }
    }

    private var playButton: some View {
        Button(action: vm.togglePlayPause) {
            ZStack {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 54, height: 54)
                    .shadow(color: Theme.cyan.opacity(0.55), radius: 14)
                    .shadow(color: Theme.purple.opacity(0.45), radius: 14)
                Circle()
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                    .frame(width: 54, height: 54)
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                    .offset(x: vm.isPlaying ? 0 : 2)
            }
        }
        .buttonStyle(GlowingButtonStyle())
        .keyboardShortcut(.space, modifiers: [])
    }

    private func iconButton(systemName: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 34, height: 34)
                .foregroundStyle(
                    isActive
                        ? AnyShapeStyle(Theme.accent)
                        : AnyShapeStyle(Color.white.opacity(0.88))
                )
        }
        .buttonStyle(IconButtonStyle())
    }

    private var volumeControl: some View {
        HStack(spacing: 8) {
            Image(systemName: speakerIcon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 20)
            GradientSlider(
                value: Binding(
                    get: { Double(vm.volume) },
                    set: { vm.setVolume(Float($0)) }
                ),
                range: 0...1,
                onCommit: {}
            )
            .frame(width: 100, height: 18)
        }
        .padding(.leading, 4)
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private var speakerIcon: String {
        if vm.volume == 0 { return "speaker.slash.fill" }
        if vm.volume < 0.34 { return "speaker.wave.1.fill" }
        if vm.volume < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

struct GradientSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onCommit: () -> Void

    @State private var isDragging = false
    @State private var isHovering = false

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let span = max(range.upperBound - range.lowerBound, 0.0001)
            let progress = min(max((value - range.lowerBound) / span, 0), 1)
            let knobX = width * progress
            let knobSize: CGFloat = isDragging ? 16 : (isHovering ? 13 : 10)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.18))
                    .frame(height: 4)

                Capsule()
                    .fill(Theme.accentHorizontal)
                    .frame(width: max(0, knobX), height: 4)
                    .shadow(color: Theme.cyan.opacity(0.55), radius: 6)

                Circle()
                    .fill(.white)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: Theme.cyan.opacity(0.6), radius: isDragging ? 8 : 4)
                    .offset(x: knobX - knobSize / 2)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: knobSize)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging { isDragging = true }
                        let p = max(0, min(1, gesture.location.x / width))
                        value = range.lowerBound + p * span
                    }
                    .onEnded { _ in
                        isDragging = false
                        onCommit()
                    }
            )
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(.white.opacity(hovering ? 0.12 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GlowingButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : (hovering ? 1.05 : 1.0))
            .onHover { hovering = $0 }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hovering)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
