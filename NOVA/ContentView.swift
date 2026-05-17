import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var vm: PlayerViewModel
    @State private var isTargeted = false
    @State private var pulseGlow = false
    @State private var showControls = true
    @State private var hideWorkItem: DispatchWorkItem?

    private var shouldShowChrome: Bool {
        guard vm.mediaURL != nil else { return false }
        if vm.isLoading || vm.isTranscoding { return false }
        if !vm.isPlaying { return true }
        return showControls
    }

    var body: some View {
        ZStack {
            if vm.mediaURL == nil {
                ambientBackground
                placeholder
            } else {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { NSApp.keyWindow?.toggleFullScreen(nil) }
                    .onTapGesture { vm.togglePlayPause() }
            }

            if shouldShowChrome {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        engineIndicator
                    }
                    .padding(.top, 26)
                    .padding(.trailing, 22)
                    Spacer()
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if vm.mediaURL != nil && !vm.isPlaying && !vm.isLoading && !vm.isBuffering && !vm.isTranscoding {
                centerPlayButton
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            if vm.isLoading || vm.isBuffering {
                loadingOverlay
                    .transition(.opacity)
            }

            if vm.isTranscoding {
                transcodeOverlay
                    .transition(.opacity)
            }

            if shouldShowChrome {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ControlsView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }

            if isTargeted {
                dropTarget
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.isPlaying)
        .animation(.easeInOut(duration: 0.25), value: vm.isLoading)
        .animation(.easeInOut(duration: 0.25), value: vm.isBuffering)
        .animation(.easeInOut(duration: 0.25), value: vm.isTranscoding)
        .animation(.easeInOut(duration: 0.3), value: showControls)
        .onContinuousHover { phase in
            switch phase {
            case .active: revealControls()
            case .ended: hideSoon()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        .onAppear { pulseGlow = true }
    }

    private func revealControls() {
        if !showControls { showControls = true }
        scheduleHide(delay: 2.5)
    }

    private func hideSoon() {
        scheduleHide(delay: 0.8)
    }

    private func scheduleHide(delay: TimeInterval) {
        hideWorkItem?.cancel()
        let work = DispatchWorkItem { showControls = false }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private var ambientBackground: some View {
        ZStack {
            RadialGradient(
                colors: [Theme.purple.opacity(0.25), .clear],
                center: .topLeading,
                startRadius: 80,
                endRadius: 600
            )
            RadialGradient(
                colors: [Theme.cyan.opacity(0.22), .clear],
                center: .bottomTrailing,
                startRadius: 80,
                endRadius: 600
            )
        }
        .ignoresSafeArea()
        .blur(radius: 40)
        .allowsHitTesting(false)
    }

    private var placeholder: some View {
        VStack(spacing: 32) {
            HStack(spacing: 14) {
                Image(systemName: "sparkle")
                    .font(.system(size: 28, weight: .ultraLight))
                Text("NOVA")
                    .font(.system(size: 68, weight: .ultraLight))
                    .tracking(14)
            }
            .foregroundStyle(Theme.accent)
            .shadow(color: Theme.cyan.opacity(pulseGlow ? 0.6 : 0.3), radius: pulseGlow ? 32 : 18)
            .shadow(color: Theme.purple.opacity(pulseGlow ? 0.45 : 0.2), radius: pulseGlow ? 24 : 12)
            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: pulseGlow)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 12, weight: .light))
                    Text("動画ファイルをドロップ")
                        .font(.system(size: 13, weight: .light))
                    Text("·")
                        .opacity(0.4)
                    Text("⌘O で開く")
                        .font(.system(size: 13, weight: .light))
                }
                .foregroundColor(.white.opacity(0.75))

                Text("AVI · MP4 · MOV · MKV · WMV · WebM · FLV · 3GP · TS")
                    .font(.system(size: 10, weight: .light, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.32))
            }
        }
        .allowsHitTesting(false)
    }

    private var centerPlayButton: some View {
        Button(action: { vm.togglePlayPause() }) {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.45))
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle().strokeBorder(Theme.accentHorizontal, lineWidth: 2)
                    )
                    .shadow(color: Theme.cyan.opacity(0.55), radius: 22)
                    .shadow(color: Theme.purple.opacity(0.35), radius: 28)
                Image(systemName: "play.fill")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundColor(.white)
                    .offset(x: 3)
            }
        }
        .buttonStyle(.plain)
    }

    private var loadingOverlay: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.large)
                .tint(.white)
            Text(vm.isBuffering ? "バッファ中…" : "読み込み中…")
                .font(.system(size: 11, weight: .light))
                .tracking(2)
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var transcodeOverlay: some View {
        VStack(spacing: 18) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.accent)
                .shadow(color: Theme.cyan.opacity(0.6), radius: 12)
            Text(vm.transcodeStatus)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            ProgressView(value: vm.transcodeProgress)
                .progressViewStyle(.linear)
                .tint(Theme.cyan)
                .frame(width: 260)
            VStack(spacing: 4) {
                Text("Google Drive と同じく、H.264 へ HW エンコードしています")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.white.opacity(0.65))
                Text("完了後、ハードウェアデコードで滑らかに再生します")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.white.opacity(0.5))
            }
            .multilineTextAlignment(.center)
            Button("キャンセル") { vm.cancelTranscode() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.white.opacity(0.08), in: Capsule())
                .padding(.top, 4)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 30)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Theme.accentHorizontal.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 28)
    }

    private var engineIndicator: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Theme.accentHorizontal)
                .frame(width: 6, height: 6)
                .shadow(color: Theme.cyan.opacity(0.7), radius: 4)
            Text(vm.engineLabel.isEmpty ? "—" : vm.engineLabel)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(.black.opacity(0.5))
        .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .clipShape(Capsule())
    }

    private var dropTarget: some View {
        ZStack {
            Theme.accent.opacity(0.15)
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Theme.accentHorizontal, lineWidth: 2)
                .padding(20)
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 60, weight: .ultraLight))
                Text("ドロップして再生")
                    .font(.system(size: 16, weight: .light))
                    .tracking(4)
            }
            .foregroundStyle(Theme.accent)
            .shadow(color: Theme.cyan.opacity(0.6), radius: 16)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let u = item as? URL {
                url = u
            }
            if let url {
                DispatchQueue.main.async { vm.open(url: url) }
            }
        }
        return true
    }
}
