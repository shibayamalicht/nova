import SwiftUI
import UniformTypeIdentifiers
import AppKit

@main
struct NovaApp: App {
    @StateObject private var viewModel = PlayerViewModel()

    var body: some Scene {
        WindowGroup("NOVA") {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 720, minHeight: 460)
                .background(WindowInstaller(viewModel: viewModel))
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("NOVA について") { showAbout() }
            }
            CommandGroup(replacing: .newItem) {
                Button("ファイルを開く...") { openFile() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("再生") {
                Button(viewModel.isPlaying ? "一時停止" : "再生") {
                    viewModel.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(viewModel.mediaURL == nil)

                Divider()

                Button("10秒戻る") { viewModel.skip(by: -10) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .disabled(viewModel.mediaURL == nil)
                Button("10秒進む") { viewModel.skip(by: 10) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .disabled(viewModel.mediaURL == nil)
                Button("30秒戻る") { viewModel.skip(by: -30) }
                    .keyboardShortcut(.leftArrow, modifiers: .shift)
                    .disabled(viewModel.mediaURL == nil)
                Button("30秒進む") { viewModel.skip(by: 30) }
                    .keyboardShortcut(.rightArrow, modifiers: .shift)
                    .disabled(viewModel.mediaURL == nil)
                Button("先頭に戻る") { viewModel.seek(to: 0) }
                    .keyboardShortcut(.upArrow, modifiers: [.command, .shift])
                    .disabled(viewModel.mediaURL == nil)

                Divider()

                Button("音量を上げる") {
                    viewModel.setVolume(min(1, viewModel.volume + 0.1))
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                Button("音量を下げる") {
                    viewModel.setVolume(max(0, viewModel.volume - 0.1))
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
                Button(viewModel.volume == 0 ? "ミュート解除" : "ミュート") {
                    viewModel.setVolume(viewModel.volume > 0 ? 0 : 1)
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }
            CommandMenu("表示") {
                Button("フルスクリーン切り替え") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .control])

                Button(viewModel.isFloating ? "常に手前に表示  ✓" : "常に手前に表示") {
                    viewModel.isFloating.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Divider()

                Button("ウィンドウサイズを 720p に") { resizeWindow(width: 1280, height: 720) }
                Button("ウィンドウサイズを 1080p に") { resizeWindow(width: 1920, height: 1080) }
            }
            CommandGroup(replacing: .help) {
                Button("NOVA ヘルプ") { showHelp() }
                Button("キーボードショートカット") { showShortcuts() }
                Divider()
                Button("対応している動画形式") { showFormats() }
            }
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = VideoFormats.allowedContentTypes
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.open(url: url)
        }
    }

    private func resizeWindow(width: CGFloat, height: CGFloat) {
        guard let window = NSApp.keyWindow else { return }
        let screenFrame = window.screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: screenFrame.midX - width / 2,
            y: screenFrame.midY - height / 2
        )
        window.setFrame(NSRect(origin: origin, size: CGSize(width: width, height: height)),
                        display: true, animate: true)
    }

    private func showAbout() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 3
        let creditsText = NSAttributedString(
            string: "開発者　しばやま\nGlass-modern video player powered by VLCKit",
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .paragraphStyle: paragraph
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            NSApplication.AboutPanelOptionKey.applicationName: "NOVA",
            NSApplication.AboutPanelOptionKey.applicationVersion: "1.0",
            NSApplication.AboutPanelOptionKey.credits: creditsText,
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "©︎2026 しばやま"
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showHelp() {
        showAlert(
            title: "NOVA — 使い方",
            body: """
            macOS に最適化された 3 段階デコーダーで、ほぼ全ての動画を滑らかに再生します。

            ▶ 動画を開く
              ⌘O またはウィンドウへドラッグ&ドロップ

            ▶ 再生エンジン (自動選択)
              ①  AVPlayer + VideoToolbox … H.264 / H.265 など対応コーデックを HW デコード
              ②  ffmpeg + h264_videotoolbox … 非対応コーデックを HW で H.264 へ再エンコード
              ③  VLCKit … ffmpeg がない場合のソフトデコード フォールバック
              現在のエンジンは右上のインジケーターで確認できます。

            ▶ 再生コントロール
              スペース … 再生 / 一時停止 (動画をクリックでも可)
              ← / →    … 10秒シーク
              ⇧← / ⇧→  … 30秒シーク
              ⌘↑ / ⌘↓  … 音量調整
              ⇧⌘M     … ミュート切り替え

            ▶ 表示
              ⌃⌘F        … フルスクリーン切り替え (動画ダブルクリックでも可)
              ⇧⌘P        … 常に手前に表示 (PiP 代替)
              マウス停止  … 約 2.5 秒後にコントロール自動非表示
              マウス移動  … コントロール再表示

            ▶ ffmpeg のインストール (推奨)
              Terminal:  brew install ffmpeg
              DivX / Xvid など非対応コーデックの動画も滑らかに再生できます。
            """
        )
    }

    private func showShortcuts() {
        showAlert(
            title: "キーボードショートカット",
            body: """
            ファイル
              ⌘O  ファイルを開く
              ⌘W  ウィンドウを閉じる
              ⌘Q  NOVA を終了

            再生
              Space   再生 / 一時停止
              ← / →   10 秒シーク
              ⇧← / ⇧→ 30 秒シーク
              ⇧⌘↑    先頭へ戻る
              ⌘↑ / ⌘↓ 音量を上げる / 下げる
              ⇧⌘M    ミュート切り替え

            表示
              ⌃⌘F  フルスクリーン切り替え
              ⇧⌘P  常に手前に表示
            """
        )
    }

    private func showFormats() {
        showAlert(
            title: "対応している動画形式",
            body: """
            NOVA は 3 段階のデコーダーを自動選択し、ほぼ全ての動画を滑らかに再生します。

            ①  AVPlayer + VideoToolbox  (ハードウェアデコード)
              H.264 / H.265 / VP9 / AV1 / ProRes など、
              macOS がネイティブ対応するコーデック。最も滑らかで省電力。

            ②  ffmpeg + h264_videotoolbox  (要 brew install ffmpeg)
              DivX / Xvid / MPEG-4 ASP / 古い WMV など、
              AVPlayer が再生できないコーデックを HW で H.264 へ再エンコードしてから AVPlayer 再生。

            ③  VLCKit  (ソフトウェアデコード・フォールバック)
              ffmpeg が無い場合の最終手段。

            ▸ 対応コンテナ
              AVI · MP4 · MOV · M4V · MKV · WebM · WMV · ASF · FLV · F4V
              3GP · 3G2 · MPG · MPEG · TS · MTS · M2TS · VOB · OGV
              RM · RMVB · DivX · Xvid · MXF

            ▸ 対応コーデック
              H.264 / H.265 / VP9 / AV1 / MPEG-2 / MPEG-4 ASP (DivX, Xvid)
              WMV / VC-1 / ProRes / RealVideo など、ほぼ全形式に対応

            ▸ 音声
              AAC / MP3 / AC-3 / DTS / FLAC / Opus / Vorbis など
            """
        )
    }

    private func showAlert(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .informational
        alert.addButton(withTitle: "閉じる")
        alert.runModal()
    }
}

enum VideoFormats {
    static let extensions: [String] = [
        "avi", "mp4", "m4v", "mov", "qt",
        "mkv", "webm",
        "wmv", "asf",
        "flv", "f4v",
        "3gp", "3g2",
        "mpg", "mpeg", "mpe", "m1v", "m2v",
        "ts", "mts", "m2ts",
        "vob", "ogv", "ogm",
        "rm", "rmvb",
        "divx", "xvid", "mxf"
    ]

    static var allowedContentTypes: [UTType] {
        var types: [UTType] = [.audiovisualContent, .movie, .video]
        var seen = Set(types.map { $0.identifier })
        for ext in extensions {
            if let t = UTType(filenameExtension: ext), seen.insert(t.identifier).inserted {
                types.append(t)
            }
        }
        return types
    }

    static func isSupported(url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }
}

private final class NovaContainerView: NSView {}

private struct WindowInstaller: NSViewRepresentable {
    let viewModel: PlayerViewModel

    final class Coordinator {
        var configured = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            install(window: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard !context.coordinator.configured else { return }
        DispatchQueue.main.async {
            install(window: nsView.window, coordinator: context.coordinator)
        }
    }

    private func install(window: NSWindow?, coordinator: Coordinator) {
        guard let window, !coordinator.configured else { return }
        guard let original = window.contentView else { return }
        if original is NovaContainerView { return }

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        window.standardWindowButton(.closeButton)?.superview?.alphaValue = 0.85

        let container = NovaContainerView(frame: original.frame)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor

        // Bottom z-order: video views
        installFullSize(viewModel.avPlayerHostView, in: container)
        installFullSize(viewModel.vlcVideoView, in: container)

        // Top z-order: SwiftUI hosting view (transparent so video shows through)
        original.frame = container.bounds
        original.autoresizingMask = [.width, .height]
        original.wantsLayer = true
        original.layer?.backgroundColor = NSColor.clear.cgColor
        container.addSubview(original)

        window.contentView = container
        coordinator.configured = true
    }

    private func installFullSize(_ subview: NSView, in container: NSView) {
        subview.removeFromSuperview()
        subview.frame = container.bounds
        subview.autoresizingMask = [.width, .height]
        container.addSubview(subview)
    }
}
