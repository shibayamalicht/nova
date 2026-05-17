import Foundation
import AppKit
import AVFoundation
import VLCKit
import Combine

final class PlayerViewModel: NSObject, ObservableObject {
    @Published var mediaURL: URL?
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Float = 1.0
    @Published var isFloating: Bool = false { didSet { applyFloating() } }
    @Published private(set) var engineLabel: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isBuffering: Bool = false
    @Published private(set) var isTranscoding: Bool = false
    @Published private(set) var transcodeProgress: Double = 0
    @Published private(set) var transcodeStatus: String = ""

    let avPlayer = AVPlayer()
    let avPlayerHostView: AVPlayerHostView
    let vlcMediaPlayer: VLCMediaPlayer
    let vlcVideoView: VLCVideoView

    private enum Engine { case none, av, vlc }
    private var engine: Engine = .none

    private var lastTimePublish: TimeInterval = 0
    private var timeObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()
    private var sourceDuration: Double = 0
    private var transcodeProcess: Process?
    private var transcodedURLs: [URL] = []

    override init() {
        avPlayerHostView = AVPlayerHostView(player: avPlayer)
        vlcMediaPlayer = VLCMediaPlayer(options: [
            "--no-video-title-show",
            "--avcodec-hw=videotoolbox",
            "--no-osd",
            "--no-stats",
            "--quiet"
        ])
        vlcVideoView = VLCVideoView()
        super.init()

        vlcVideoView.fillScreen = false
        vlcVideoView.wantsLayer = true
        vlcVideoView.layer?.backgroundColor = NSColor.black.cgColor
        vlcMediaPlayer.drawable = vlcVideoView
        vlcMediaPlayer.delegate = self
        vlcMediaPlayer.audio?.volume = 100

        avPlayerHostView.isHidden = true
        vlcVideoView.isHidden = true

        let interval = CMTime(seconds: 0.25, preferredTimescale: 4)
        timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.handleAVTime(time)
        }
        avPlayer.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self, self.engine == .av else { return }
                let playing = status == .playing
                if self.isPlaying != playing { self.isPlaying = playing }
                let buffering = (status == .waitingToPlayAtSpecifiedRate)
                if self.isBuffering != buffering { self.isBuffering = buffering }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification)
            .sink { [weak self] note in
                self?.handleAVFailure(note: note)
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: AVPlayerItem.newErrorLogEntryNotification)
            .sink { [weak self] _ in
                guard let self, self.engine == .av,
                      let item = self.avPlayer.currentItem,
                      let url = self.mediaURL else { return }
                if item.status == .failed {
                    self.fallbackToVLC(url: url)
                }
            }
            .store(in: &cancellables)
    }

    func open(url: URL) {
        cancelTranscode()
        mediaURL = url
        stopAll()
        currentTime = 0
        duration = 0
        sourceDuration = 0
        isLoading = true
        isBuffering = false

        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ])
        Task { @MainActor [weak self] in
            guard let self else { return }
            var canPlayInAV = false
            do {
                let isPlayable = try await asset.load(.isPlayable)
                let tracks = try await asset.load(.tracks)
                let hasVideo = tracks.contains { $0.mediaType == .video }
                canPlayInAV = isPlayable && hasVideo
                if let dur = try? await asset.load(.duration) {
                    self.sourceDuration = CMTimeGetSeconds(dur)
                }
            } catch {
                canPlayInAV = false
            }

            if canPlayInAV {
                self.playWithAV(asset: asset)
                self.isLoading = false
            } else if FFmpegService.shared.isAvailable {
                self.isLoading = false
                self.transcodeAndPlay(url: url)
            } else {
                self.playWithVLC(url: url)
                self.isLoading = false
            }
        }
    }

    private func transcodeAndPlay(url: URL) {
        isTranscoding = true
        transcodeProgress = 0
        transcodeStatus = "ffmpeg を起動中…"

        transcodeProcess = FFmpegService.shared.transcode(
            sourceURL: url,
            hintDuration: sourceDuration,
            onStatus: { [weak self] status in
                self?.transcodeStatus = status
            },
            onProgress: { [weak self] prog in
                self?.transcodeProgress = prog
            },
            onComplete: { [weak self] result in
                guard let self else { return }
                self.transcodeProcess = nil
                self.isTranscoding = false
                self.transcodeProgress = 0
                switch result {
                case .success(let outURL):
                    self.transcodedURLs.append(outURL)
                    self.transcodeStatus = "完了"
                    let outAsset = AVURLAsset(url: outURL)
                    self.playWithAV(asset: outAsset)
                case .failure(let err):
                    self.transcodeStatus = err.localizedDescription
                    self.playWithVLC(url: url)
                }
            }
        )
    }

    func cancelTranscode() {
        if let p = transcodeProcess, p.isRunning {
            p.terminate()
        }
        transcodeProcess = nil
        if isTranscoding {
            isTranscoding = false
            transcodeProgress = 0
        }
    }

    deinit {
        if let token = timeObserverToken {
            avPlayer.removeTimeObserver(token)
        }
        for url in transcodedURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func playWithAV(asset: AVAsset) {
        vlcVideoView.isHidden = true
        let item = AVPlayerItem(asset: asset)
        avPlayer.replaceCurrentItem(with: item)
        avPlayer.volume = volume
        avPlayer.play()
        avPlayerHostView.isHidden = false
        engine = .av
        engineLabel = "AVPlayer · HW"
        isPlaying = true
    }

    private func playWithVLC(url: URL) {
        avPlayerHostView.isHidden = true
        let media = VLCMedia(url: url)
        media.addOption(":avcodec-hw=videotoolbox")
        media.addOption(":no-video-title-show")
        vlcMediaPlayer.media = media
        vlcMediaPlayer.play()
        vlcVideoView.isHidden = false
        engine = .vlc
        engineLabel = "VLCKit · SW"
        isPlaying = true
    }

    private func fallbackToVLC(url: URL) {
        guard engine == .av else { return }
        avPlayer.pause()
        avPlayer.replaceCurrentItem(with: nil)
        playWithVLC(url: url)
    }

    private func handleAVFailure(note: Notification) {
        guard engine == .av, let url = mediaURL else { return }
        fallbackToVLC(url: url)
    }

    private func stopAll() {
        if avPlayer.timeControlStatus == .playing { avPlayer.pause() }
        if vlcMediaPlayer.isPlaying { vlcMediaPlayer.pause() }
        engine = .none
    }

    func togglePlayPause() {
        switch engine {
        case .av:
            if avPlayer.timeControlStatus == .playing { avPlayer.pause() }
            else { avPlayer.play() }
        case .vlc:
            if vlcMediaPlayer.isPlaying { vlcMediaPlayer.pause() }
            else { vlcMediaPlayer.play() }
        case .none:
            break
        }
    }

    func seek(to seconds: Double) {
        switch engine {
        case .av:
            avPlayer.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
            currentTime = seconds
        case .vlc:
            guard duration > 0 else { return }
            vlcMediaPlayer.position = Float(min(max(seconds / duration, 0), 1))
            currentTime = seconds
        case .none:
            break
        }
    }

    func skip(by seconds: Double) {
        let target = max(0, min(duration, currentTime + seconds))
        seek(to: target)
    }

    func setVolume(_ value: Float) {
        let clamped = min(max(value, 0), 1)
        volume = clamped
        switch engine {
        case .av: avPlayer.volume = clamped
        case .vlc: vlcMediaPlayer.audio?.volume = Int32(clamped * 100)
        case .none: break
        }
    }

    private func applyFloating() {
        let window = NSApp.keyWindow ?? NSApp.windows.first
        window?.level = isFloating ? .floating : .normal
    }

    private func handleAVTime(_ time: CMTime) {
        guard engine == .av else { return }
        currentTime = CMTimeGetSeconds(time)
        if let item = avPlayer.currentItem {
            let dur = CMTimeGetSeconds(item.duration)
            if dur.isFinite && abs(dur - duration) > 0.5 {
                duration = dur
            }
        }
    }
}

extension PlayerViewModel: VLCMediaPlayerDelegate {
    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        guard engine == .vlc else { return }
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastTimePublish >= 0.25 else { return }
        lastTimePublish = now
        let timeMs = Double(vlcMediaPlayer.time.intValue)
        currentTime = timeMs / 1000.0
        if let lengthMs = vlcMediaPlayer.media?.length.intValue, lengthMs > 0 {
            let newDuration = Double(lengthMs) / 1000.0
            if abs(newDuration - duration) > 0.5 {
                duration = newDuration
            }
        }
    }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard engine == .vlc else { return }
        let playing = vlcMediaPlayer.isPlaying
        if isPlaying != playing { isPlaying = playing }
    }
}
