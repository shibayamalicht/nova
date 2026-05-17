# NOVA

> ✦ Glass-modern video player for macOS — plays anything as smoothly as Google Drive's preview, including legacy AVI codecs.
> ✦ macOS 向けグラスモーフィズム動画プレイヤー — レガシー AVI コーデックも Google Drive のプレビュー並みに滑らかに再生します。

NOVA is a macOS video player that aims to play **every** container — AVI, MKV, WMV, and more — with full **hardware acceleration**, even when the underlying codec isn't natively supported by macOS.

NOVA は AVI / MKV / WMV など macOS が標準では再生できないコーデックも含めて、**フルハードウェアアクセラレーション**で滑らかに再生することを目指した macOS 用ビデオプレイヤーです。

---

## ✨ Features / 特徴

- 🎬 **Three-tier auto decoder pipeline** / **3 段階の自動デコーダー選択** — AVPlayer + VideoToolbox → ffmpeg re-encode → VLCKit fallback
- ⚡ **Hardware acceleration end-to-end** / **入出力ともハードウェアアクセラレーション** — VideoToolbox for decode, `h264_videotoolbox` for encode
- 🪟 **Glassmorphism UI** / **グラスモーフィズム UI** — `NSVisualEffectView` with a cyan→purple accent gradient
- 🖱 **Drag & drop** / **ドラッグ&ドロップ対応** — recognizes 27 video container types / 27 種類の動画コンテナを認識
- 📌 **Always on top (PiP alternative)** / **常に手前に表示 (PiP 代替)** — floating window, since system PiP is incompatible with VLC
- 🎯 **Engine indicator** / **エンジンインジケーター** — shows which decoder is currently active (top-right corner) / 現在のデコーダーを右上に表示
- 🌑 **Auto-hiding controls** / **コントロール自動非表示** — controls fade out 2.5 s after the mouse stops during playback / 再生中はマウス停止 2.5 秒で消える
- 🎨 **Native-feeling app icon** / **macOS-native アイコン** — generated dynamically by a Swift script

---

## 🏗 Architecture / アーキテクチャ

NOVA picks the cheapest viable decoder for each file, automatically.
NOVA は動画ごとに**最も負荷の低いデコーダー**を自動選択します。

```
                ┌────────────────────────┐
                │  Drop a video file     │
                │  動画ファイルをドロップ    │
                └───────────┬────────────┘
                            ▼
                ┌────────────────────────────┐
                │ Async probe via            │
                │ AVAsset.isPlayable         │
                │ (非同期判定)                │
                └──────────────┬─────────────┘
                               │
         ┌─────────── ✅ Yes ───┴──── ❌ No ──────┐
         ▼                                       ▼
┌────────────────────┐               ┌──────────────────────┐
│  AVPlayer +         │               │ Is ffmpeg installed? │
│  VideoToolbox HW    │               │ ffmpeg はあるか?      │
│  (Google Drive-      │               └──────┬───────────────┘
│   level smoothness) │                      │
└────────────────────┘              ✅ Yes ──┴── ❌ No
                                       │            │
                                       ▼            ▼
                       ┌────────────────────────┐  ┌──────────────────┐
                       │ ffmpeg                 │  │ VLCKit           │
                       │ h264_videotoolbox      │  │ software decode  │
                       │ HW re-encode → MP4     │  │ (ソフトデコード)  │
                       │   → AVPlayer playback  │  │ (last resort)    │
                       └────────────────────────┘  └──────────────────┘
```

### Why this design / 設計の根拠

- **Codecs macOS understands natively** (H.264 / H.265 / VP9 / AV1) play perfectly through AVPlayer on the GPU — there's no reason to second-guess it.
  **macOS が直接デコードできるコーデック** (H.264 / H.265 / VP9 / AV1) は AVPlayer に任せれば GPU で完璧に滑らかに再生されます。
- **Legacy AVI codecs** (DivX / Xvid / MPEG-4 ASP) aren't supported by AVFoundation, but `h264_videotoolbox` can re-encode them to H.264 on dedicated silicon faster than they can be played back. The output is then handed off to AVPlayer for HW decode.
  **古い AVI のコーデック** (DivX / Xvid / MPEG-4 ASP 等) は AVFoundation 非対応ですが、`h264_videotoolbox` を使えば再生速度より速く H.264 へ HW 再エンコードできます。出力は AVPlayer の HW デコードに渡されます。
- **VLCKit** uses CPU-based software decoding. It's only reached when ffmpeg is unavailable — a safety net for "it should still play *something*."
  **VLCKit** は CPU ソフトデコードのため低速ですが、ffmpeg が無い環境のための最終手段として残してあります。

---

## 📦 Requirements / 必要環境

| Item / 項目 | Required / 要件 |
|------|----------|
| macOS | 13.0 (Ventura) or later / 13.0 (Ventura) 以降 |
| Architecture / アーキテクチャ | Intel or Apple Silicon / どちらも可 |
| Build toolchain / ビルド | Xcode or just Command Line Tools / Xcode または CLT |
| **ffmpeg (recommended / 推奨)** | `brew install ffmpeg` — HW re-encoding for unsupported codecs / 非対応コーデックの自動再エンコードに使用 |

---

## 🚀 Build / ビルド

### 1. Grab dependencies / 依存物を取得

**VLCKit** (required / 必須, ~84 MB)

```bash
cd nova
curl -L -o vlckit.tar.xz "https://download.videolan.org/pub/cocoapods/prod/VLCKit-3.7.3-319ed2c0-79128878.tar.xz"
tar -xJf vlckit.tar.xz
mv "VLCKit - binary package/VLCKit.xcframework" Frameworks/
rm -rf "VLCKit - binary package" vlckit.tar.xz
```

Check [https://download.videolan.org/pub/cocoapods/prod/](https://download.videolan.org/pub/cocoapods/prod/) for the latest VLCKit version.
最新版は [https://download.videolan.org/pub/cocoapods/prod/](https://download.videolan.org/pub/cocoapods/prod/) で確認できます。

**ffmpeg** (recommended / 推奨)

```bash
brew install ffmpeg
```

### 2. Build / ビルド

```bash
./build.sh         # produces build/NOVA.app   /  build/NOVA.app を生成
./build.sh run     # build, then launch        /  ビルド & 起動
./build.sh clean   # remove build artifacts    /  ビルド成果物を削除
```

You don't need Xcode — **Command Line Tools** alone are enough (`xcrun swiftc` is used directly).
Xcode が無くても **Command Line Tools** だけでビルドできます (`xcrun swiftc` で直接コンパイル)。

### 3. Want to use Xcode? / Xcode を使う場合

A `project.yml` is included for XcodeGen.
XcodeGen 用の `project.yml` を同梱しています。

```bash
brew install xcodegen
xcodegen generate
open Nova.xcodeproj
```

---

## ⌨️ Keyboard Shortcuts / キーボードショートカット

| Key / キー | Action / 動作 |
|-----|--------|
| `⌘O` | Open file / ファイルを開く |
| `Space` | Play / pause (click the video too) / 再生・一時停止 (動画クリックでも可) |
| `←` / `→` | Seek ±10 s / 10秒シーク |
| `⇧←` / `⇧→` | Seek ±30 s / 30秒シーク |
| `⇧⌘↑` | Jump to start / 先頭へ戻る |
| `⌘↑` / `⌘↓` | Volume ±10% / 音量 ±10% |
| `⇧⌘M` | Toggle mute / ミュート切替 |
| `⌃⌘F` | Toggle fullscreen (double-click too) / フルスクリーン切替 (ダブルクリックでも可) |
| `⇧⌘P` | Always on top / 常に手前に表示 |
| `⌘W` | Close window / ウィンドウを閉じる |
| `⌘Q` | Quit NOVA / NOVA を終了 |

---

## 🎞 Supported Formats / 対応フォーマット

| Category / カテゴリ | Extensions / 拡張子 |
|----------|------------|
| General / 一般 | `avi` `mp4` `m4v` `mov` `qt` |
| High-quality containers / 高画質コンテナ | `mkv` `webm` |
| Windows | `wmv` `asf` |
| Streaming / ストリーミング | `flv` `f4v` `ts` `mts` `m2ts` |
| Mobile / モバイル | `3gp` `3g2` |
| MPEG | `mpg` `mpeg` `mpe` `m1v` `m2v` |
| Other / その他 | `vob` `ogv` `ogm` `rm` `rmvb` `divx` `xvid` `mxf` |

---

## 🛠 Tech Stack / 技術スタック

| Layer / レイヤー | Technology / 技術 |
|-------|------------|
| UI | SwiftUI (macOS 13+) |
| Window integration / ウィンドウ統合 | Custom container — video views as siblings of a transparent `NSHostingView` / 動画ビューと透過 `NSHostingView` を兄弟関係に配置するカスタムコンテナ |
| Playback engines / 再生エンジン | `AVPlayer` + `AVPlayerLayer` / `VLCKit 3.7.3` |
| Decoders / デコーダー | `VideoToolbox` (HW) / `libavcodec` (SW) |
| Transcoder / トランスコーダー | `ffmpeg` with `h264_videotoolbox` (HW encode) |
| Glass effect / ガラスエフェクト | `NSVisualEffectView` (.hudWindow) |
| App icon / アプリアイコン | Generated by a Swift script + `iconutil` |

---

## 📁 Project Structure / プロジェクト構成

```
nova/
├── README.md
├── build.sh                  # Build script (CLT only) / CLT 用ビルドスクリプト
├── project.yml               # XcodeGen config (optional) / XcodeGen 設定 (任意)
├── make_icon.swift           # Icon generator / アイコン生成
├── Frameworks/               # VLCKit.xcframework (gitignored)
└── NOVA/
    ├── NovaApp.swift         # @main / WindowGroup / menus / About panel
    ├── ContentView.swift     # Main view: placeholder / controls / overlays
    ├── ControlsView.swift    # Bottom bar (play / seek / volume / etc.)
    ├── PlayerViewModel.swift # AVPlayer + VLCKit + ffmpeg orchestration
    ├── AVPlayerHostView.swift # NSView hosting AVPlayerLayer
    ├── FFmpegService.swift   # ffmpeg detection + async transcode + progress
    ├── Theme.swift           # Colors & gradients
    ├── VisualEffectView.swift # NSVisualEffectView wrapper
    ├── Info.plist
    ├── Nova.entitlements
    └── AppIcon.icns
```

---

## 💡 Implementation Notes / 実装ポイント

### Container architecture / コンテナアーキテクチャ

Adding a video view as a subview of SwiftUI's `NSHostingView` puts the video **on top of** the SwiftUI rendering in AppKit's draw order — controls become invisible.
SwiftUI の `NSHostingView` に動画ビューをサブビューとして追加すると、AppKit の描画順序的に動画が SwiftUI の上に描画されてしまい、コントロールが見えなくなります。

NOVA solves this by replacing the window's `contentView` with a custom container:
NOVA はウィンドウの `contentView` をカスタムコンテナで包むことで解決:

```
NSWindow
└─ contentView = NovaContainerView (NSView)
   ├─ [0] AVPlayerHostView ←─ video (back / 最背面)
   ├─ [1] VLCVideoView     ←─ video (back / 最背面)
   └─ [2] NSHostingView    ←─ SwiftUI controls (transparent, front / 透過・最前面)
```

Setting `NSHostingView.layer.backgroundColor = .clear` lets the SwiftUI overlay sit cleanly above the video.
`NSHostingView.layer.backgroundColor = .clear` で透過させ、SwiftUI のコントロールが動画の上に綺麗に重なります。

### A/V sync recovery / A/V 同期改善

When VLC's software decode can't keep up, NOVA shells out to ffmpeg with `h264_videotoolbox` to re-encode the file into MP4 using dedicated silicon. The resulting file is then decoded by AVPlayer (also on hardware) — the equivalent of what Google Drive does server-side, but on your machine.
VLC のソフトデコードでカクつく場合、NOVA は ffmpeg + `h264_videotoolbox` を使って Apple Silicon / Intel VideoToolbox 上で H.264 MP4 へ再エンコードし、AVPlayer の HW デコードに渡します。Google Drive がサーバー側でやっていることを、ローカルで実行する形です。

Progress is parsed live from ffmpeg's stderr (`Duration:` for the source length, `time=` for the current encode position).
エンコード進捗は ffmpeg の stderr (`Duration:` でソース全長、`time=` で現在位置) をリアルタイムにパースして表示します。

---

## 📜 License

MIT License.

---

## 👤 Credits

- Developed by / 開発: **しばやま**
- © 2026 しばやま
- VLCKit: [VideoLAN](https://www.videolan.org/)
- ffmpeg: [FFmpeg](https://ffmpeg.org/)
