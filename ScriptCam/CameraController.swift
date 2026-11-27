import AVFoundation
import AppKit
import SwiftUI

final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "scriptcam.session")
    private let movieOutput = AVCaptureMovieFileOutput()

    @Published var isConfigured = false
    @Published var isRecording = false
    @Published var status = "Preparing camera…"
    @Published var elapsed = "00:00"
    @Published var lastSavedURL: URL?
    @Published var exportMessage = ""

    private var startedAt: Date?
    private var timer: Timer?

    func configure() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let camera = AVCaptureDevice.default(for: .video),
                  let videoInput = try? AVCaptureDeviceInput(device: camera),
                  self.session.canAddInput(videoInput) else {
                DispatchQueue.main.async { self.status = "No compatible camera found." }
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(videoInput)

            if let mic = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: mic),
               self.session.canAddInput(audioInput) {
                self.session.addInput(audioInput)
            }

            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
            }

            self.session.commitConfiguration()
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isConfigured = true
                self.status = "Camera ready"
            }
        }
    }

    func startRecording() {
        guard !movieOutput.isRecording else { return }
        let panel = NSSavePanel()
        panel.title = "Save ScriptCam recording"
        panel.nameFieldStringValue = "ScriptCam-\(Self.timestamp()).mov"
        panel.allowedContentTypes = [.quickTimeMovie]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        lastSavedURL = url
        sessionQueue.async {
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
            DispatchQueue.main.async {
                self.isRecording = true
                self.startedAt = Date()
                self.status = "Recording"
                self.startClock()
            }
        }
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        sessionQueue.async { self.movieOutput.stopRecording() }
        DispatchQueue.main.async {
            self.isRecording = false
            self.timer?.invalidate()
            self.timer = nil
            self.status = "Finishing recording…"
        }
    }

    private func startClock() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let startedAt = self.startedAt else { return }
            let seconds = Int(Date().timeIntervalSince(startedAt))
            self.elapsed = String(format: "%02d:%02d", seconds / 60, seconds % 60)
        }
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }

    func exportMP4(from sourceURL: URL) {
        let destination = sourceURL.deletingPathExtension().appendingPathExtension("mp4")
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }
        guard let export = AVAssetExportSession(asset: AVURLAsset(url: sourceURL),
                                                presetName: AVAssetExportPresetHighestQuality),
              export.supportedFileTypes.contains(.mp4) else {
            DispatchQueue.main.async { self.exportMessage = "MP4 export is unavailable for this recording." }
            return
        }
        export.outputURL = destination
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true
        export.exportAsynchronously {
            DispatchQueue.main.async {
                self.exportMessage = export.status == .completed
                    ? "MP4 saved: \(destination.lastPathComponent)"
                    : "MP4 export failed: \(export.error?.localizedDescription ?? "Unknown error")"
            }
        }
    }
}

extension CameraController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.status = error == nil ? "MOV saved" : "Recording error: \(error!.localizedDescription)"
            if error == nil {
                self.lastSavedURL = outputFileURL
                self.exportMessage = "MOV saved. Creating MP4 copy…"
                self.exportMP4(from: outputFileURL)
            }
        }
    }
}
