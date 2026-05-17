import Foundation
import AppKit

enum FFmpegError: LocalizedError {
    case notInstalled
    case launchFailed(String)
    case transcodeFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "ffmpeg がインストールされていません"
        case .launchFailed(let msg):
            return "ffmpeg の起動に失敗: \(msg)"
        case .transcodeFailed(let code):
            return "ffmpeg の変換に失敗 (exit \(code))"
        }
    }
}

final class FFmpegService {
    static let shared = FFmpegService()

    private static let candidatePaths = [
        "/usr/local/bin/ffmpeg",
        "/opt/homebrew/bin/ffmpeg",
        "/usr/bin/ffmpeg"
    ]

    private init() {}

    func ffmpegPath() -> String? {
        Self.candidatePaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    var isAvailable: Bool { ffmpegPath() != nil }

    @discardableResult
    func transcode(
        sourceURL: URL,
        hintDuration: Double,
        onStatus: @escaping (String) -> Void,
        onProgress: @escaping (Double) -> Void,
        onComplete: @escaping (Result<URL, Error>) -> Void
    ) -> Process? {
        guard let path = ffmpegPath() else {
            onComplete(.failure(FFmpegError.notInstalled))
            return nil
        }

        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nova_\(UUID().uuidString.prefix(8))")
            .appendingPathExtension("mp4")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = [
            "-y",
            "-hide_banner",
            "-loglevel", "info",
            "-i", sourceURL.path,
            "-c:v", "h264_videotoolbox",
            "-b:v", "5M",
            "-allow_sw", "1",
            "-c:a", "aac",
            "-b:a", "192k",
            outputURL.path
        ]

        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = Pipe()

        let parser = FFmpegOutputParser(initialDuration: hintDuration)
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            parser.consume(str)
            let snapshot = parser.snapshot()
            DispatchQueue.main.async {
                if let progress = snapshot.progress {
                    onProgress(progress)
                }
                if let status = snapshot.status {
                    onStatus(status)
                }
            }
        }

        process.terminationHandler = { proc in
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                if proc.terminationStatus == 0,
                   FileManager.default.fileExists(atPath: outputURL.path) {
                    onProgress(1.0)
                    onComplete(.success(outputURL))
                } else {
                    onComplete(.failure(FFmpegError.transcodeFailed(proc.terminationStatus)))
                }
            }
        }

        do {
            try process.run()
            onStatus("変換準備中…")
            return process
        } catch {
            onComplete(.failure(FFmpegError.launchFailed("\(error)")))
            return nil
        }
    }
}

private final class FFmpegOutputParser {
    struct Snapshot {
        var progress: Double?
        var status: String?
    }

    private var buffer = ""
    private var duration: Double
    private var lastReportedProgress: Double = -1
    private let queue = DispatchQueue(label: "ffmpeg.parser")

    init(initialDuration: Double) {
        self.duration = initialDuration > 0 ? initialDuration : 0
    }

    func consume(_ chunk: String) {
        queue.sync { buffer.append(chunk) }
    }

    func snapshot() -> Snapshot {
        queue.sync {
            if duration <= 0 {
                duration = Self.parseDuration(buffer) ?? 0
            }
            var snap = Snapshot()
            if let curSec = Self.parseLastTime(buffer) {
                if duration > 0 {
                    let progress = min(curSec / duration, 1.0)
                    if abs(progress - lastReportedProgress) > 0.005 {
                        lastReportedProgress = progress
                        snap.progress = progress
                        snap.status = String(format: "H.264 に変換中  %3.0f%%  (%@)",
                                              progress * 100,
                                              Self.timeString(curSec))
                    }
                } else {
                    snap.status = String(format: "H.264 に変換中…  処理位置 %@", Self.timeString(curSec))
                }
            }
            return snap
        }
    }

    private static func parseDuration(_ output: String) -> Double? {
        let pattern = #"Duration:\s*(\d+):(\d+):(\d+)\.(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)) else {
            return nil
        }
        func extract(_ group: Int) -> Double {
            guard let range = Range(match.range(at: group), in: output) else { return 0 }
            return Double(output[range]) ?? 0
        }
        let total = extract(1) * 3600 + extract(2) * 60 + extract(3)
        return total > 0 ? total : nil
    }

    private static func parseLastTime(_ output: String) -> Double? {
        let pattern = #"time=(\d+):(\d+):(\d+)\.(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
        guard let last = matches.last else { return nil }
        func extract(_ group: Int) -> Double {
            guard let range = Range(last.range(at: group), in: output) else { return 0 }
            return Double(output[range]) ?? 0
        }
        return extract(1) * 3600 + extract(2) * 60 + extract(3)
    }

    private static func timeString(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
