import AVFoundation
import AppKit
import SwiftUI

final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "scriptcam.session")
    private let movieOutput = AVCaptureMovieFileOutput()
    private let audioDataOutput = AVCaptureAudioDataOutput()
    private let audioMeterQueue = DispatchQueue(label: "scriptcam.audio-meter")

    private var recordingAspectRatio: RecordingAspectRatio = .landscape
    private var recordingFramingMode: RecordingFramingMode = .crop



    @Published var isConfigured = false
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var audioLevel: CGFloat = 0
    @Published var isAudioClipping = false
    @Published var status = "Preparing camera…"
    @Published var elapsed = "00:00"
    @Published var lastSavedURL: URL?
    @Published var exportMessage = ""
    // Available recording devices
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var availableMicrophones: [AVCaptureDevice] = []

    // Currently selected devices
    @Published var selectedCameraID: String = ""
    @Published var selectedMicrophoneID: String = ""

    private var startedAt: Date?
    private var pausedAt: Date?
    private var totalPausedDuration: TimeInterval = 0
    private var timer: Timer?
    private func discoverDevices() {
        let videoDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .externalUnknown
            ],
            mediaType: .video,
            position: .unspecified
        )

        let audioDevices = AVCaptureDevice.devices(for: .audio)

        DispatchQueue.main.async {
            self.availableCameras = videoDiscovery.devices
            self.availableMicrophones = audioDevices

            if self.selectedCameraID.isEmpty {
                self.selectedCameraID = videoDiscovery.devices.first?.uniqueID ?? ""
            }

            if self.selectedMicrophoneID.isEmpty {
                self.selectedMicrophoneID = audioDevices.first?.uniqueID ?? ""
            }
        }
    }

    func configure() {
        sessionQueue.async {
            guard !self.isConfigured else { return }

            let videoDiscovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .builtInWideAngleCamera,
                    .externalUnknown
                ],
                mediaType: .video,
                position: .unspecified
            )

            let cameras = videoDiscovery.devices
            let microphones = AVCaptureDevice.devices(for: .audio)

            DispatchQueue.main.async {
                self.availableCameras = cameras
                self.availableMicrophones = microphones

                if self.selectedCameraID.isEmpty {
                    self.selectedCameraID = cameras.first?.uniqueID ?? ""
                }

                if self.selectedMicrophoneID.isEmpty {
                    self.selectedMicrophoneID = microphones.first?.uniqueID ?? ""
                }
            }

            guard
                let camera = cameras.first,
                let videoInput = try? AVCaptureDeviceInput(device: camera),
                self.session.canAddInput(videoInput)
            else {
                DispatchQueue.main.async {
                    self.status = "No compatible camera found."
                }
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            self.session.addInput(videoInput)

            if let microphone = microphones.first,
               let audioInput = try? AVCaptureDeviceInput(device: microphone),
               self.session.canAddInput(audioInput) {
                self.session.addInput(audioInput)
            }

            guard self.session.canAddOutput(self.movieOutput) else {
                self.session.commitConfiguration()

                DispatchQueue.main.async {
                    self.status = "Unable to configure recording output."
                }
                return
            }

            self.session.addOutput(self.movieOutput)

            if self.session.canAddOutput(self.audioDataOutput) {
                self.session.addOutput(self.audioDataOutput)
                self.audioDataOutput.setSampleBufferDelegate(
                    self,
                    queue: self.audioMeterQueue
                )
            }

            self.session.commitConfiguration()
            self.session.startRunning()

            DispatchQueue.main.async {
                self.isConfigured = true
                self.status = "Camera ready"
            }
        }
    }


    func selectCamera(id: String) {
        guard !isRecording else { return }

        sessionQueue.async {
            guard let device = self.availableCameras.first(where: {
                $0.uniqueID == id
            }) else { return }

            // Avoid reconnecting the camera already in use.
            let currentVideoDevice = self.session.inputs
                .compactMap { $0 as? AVCaptureDeviceInput }
                .first(where: { $0.device.hasMediaType(.video) })

            guard currentVideoDevice?.device.uniqueID != device.uniqueID else {
                return
            }

            do {
                let newInput = try AVCaptureDeviceInput(device: device)

                self.session.beginConfiguration()

                let oldInputs = self.session.inputs.compactMap {
                    $0 as? AVCaptureDeviceInput
                }.filter {
                    $0.device.hasMediaType(.video)
                }

                oldInputs.forEach {
                    self.session.removeInput($0)
                }

                guard self.session.canAddInput(newInput) else {
                    oldInputs.forEach {
                        if self.session.canAddInput($0) {
                            self.session.addInput($0)
                        }
                    }

                    self.session.commitConfiguration()
                    return
                }

                self.session.addInput(newInput)
                self.session.commitConfiguration()

                DispatchQueue.main.async {
                    self.selectedCameraID = id
                    self.status = "Camera ready"
                }

            } catch {
                DispatchQueue.main.async {
                    self.status = "Camera switch failed: \(error.localizedDescription)"
                }
            }
        }
    }



    func selectMicrophone(id: String) {
        guard !isRecording else { return }

        sessionQueue.async {
            guard let device = self.availableMicrophones.first(where: {
                $0.uniqueID == id
            }) else { return }

            // Avoid reconnecting the microphone already in use.
            let currentAudioDevice = self.session.inputs
                .compactMap { $0 as? AVCaptureDeviceInput }
                .first(where: { $0.device.hasMediaType(.audio) })

            guard currentAudioDevice?.device.uniqueID != device.uniqueID else {
                return
            }

            do {
                let newInput = try AVCaptureDeviceInput(device: device)

                self.session.beginConfiguration()

                let oldInputs = self.session.inputs.compactMap {
                    $0 as? AVCaptureDeviceInput
                }.filter {
                    $0.device.hasMediaType(.audio)
                }

                oldInputs.forEach {
                    self.session.removeInput($0)
                }

                guard self.session.canAddInput(newInput) else {
                    oldInputs.forEach {
                        if self.session.canAddInput($0) {
                            self.session.addInput($0)
                        }
                    }

                    self.session.commitConfiguration()
                    return
                }

                self.session.addInput(newInput)
                self.session.commitConfiguration()

                DispatchQueue.main.async {
                    self.selectedMicrophoneID = id
                    self.status = "Microphone updated"
                }

            } catch {
                DispatchQueue.main.async {
                    self.status = "Microphone switch failed: \(error.localizedDescription)"
                }
            }
        }
    }



    func startRecording(
        aspectRatio: RecordingAspectRatio,
        framingMode: RecordingFramingMode
    ) {
        guard !movieOutput.isRecording else { return }

        recordingAspectRatio = aspectRatio
        recordingFramingMode = framingMode

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

    func pauseRecording() {
        guard movieOutput.isRecording, !isPaused else { return }

        sessionQueue.async {
            self.movieOutput.pauseRecording()

            DispatchQueue.main.async {
                self.isPaused = true
                self.pausedAt = Date()
                self.status = "Recording paused"
            }
        }
    }

    func resumeRecording() {
        guard movieOutput.isRecording, isPaused else { return }

        sessionQueue.async {
            self.movieOutput.resumeRecording()

            DispatchQueue.main.async {
                if let pausedAt = self.pausedAt {
                    self.totalPausedDuration += Date().timeIntervalSince(pausedAt)
                }

                self.pausedAt = nil
                self.isPaused = false
                self.status = "Recording"
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

            let currentPauseDuration = self.pausedAt.map {
                Date().timeIntervalSince($0)
            } ?? 0

            let activeDuration = Date().timeIntervalSince(startedAt)
                - self.totalPausedDuration
                - currentPauseDuration

            let seconds = max(0, Int(activeDuration))

            self.elapsed = String(
                format: "%02d:%02d",
                seconds / 60,
                seconds % 60
            )
        }
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }

    func exportMP4(from sourceURL: URL) {
        let destination = sourceURL
            .deletingPathExtension()
            .appendingPathExtension("mp4")

        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }

        let asset = AVURLAsset(url: sourceURL)

        guard
            let videoTrack = asset.tracks(withMediaType: .video).first,
            let export = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetHighestQuality
            ),
            export.supportedFileTypes.contains(.mp4)
        else {
            DispatchQueue.main.async {
                self.exportMessage = "MP4 export is unavailable for this recording."
            }
            return
        }

        let targetLongSide: CGFloat = 1920
        let ratio = recordingAspectRatio.value

        let renderSize: CGSize

        if ratio >= 1 {
            renderSize = CGSize(
                width: targetLongSide,
                height: targetLongSide / ratio
            )
        } else {
            renderSize = CGSize(
                width: targetLongSide * ratio,
                height: targetLongSide
            )
        }

        let naturalSize = videoTrack.naturalSize
        let preferredTransform = videoTrack.preferredTransform

        let transformedRect = CGRect(
            origin: .zero,
            size: naturalSize
        ).applying(preferredTransform)

        let sourceWidth = abs(transformedRect.width)
        let sourceHeight = abs(transformedRect.height)

        guard sourceWidth > 0, sourceHeight > 0 else {
            DispatchQueue.main.async {
                self.exportMessage = "Unable to determine video dimensions."
            }
            return
        }

        let widthScale = renderSize.width / sourceWidth
        let heightScale = renderSize.height / sourceHeight

        let scale: CGFloat = recordingFramingMode == .crop
            ? max(widthScale, heightScale)
            : min(widthScale, heightScale)

        let scaledWidth = sourceWidth * scale
        let scaledHeight = sourceHeight * scale

        let offsetX = (renderSize.width - scaledWidth) / 2
        let offsetY = (renderSize.height - scaledHeight) / 2

        let normalizedTransform = preferredTransform.concatenating(
            CGAffineTransform(
                translationX: -transformedRect.minX,
                y: -transformedRect.minY
            )
        )

        let finalTransform = normalizedTransform
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: offsetX, y: offsetY))

        let composition = AVMutableVideoComposition()
        composition.renderSize = renderSize
        composition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        instruction.backgroundColor = NSColor.black.cgColor

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(
            assetTrack: videoTrack
        )

        layerInstruction.setTransform(finalTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]

        export.videoComposition = composition
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

extension CameraController: AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard
            let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
            let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription),
            let audioFormat = AVAudioFormat(streamDescription: streamDescription)
        else {
            return
        }

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))

        guard let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: frameCount
        ) else {
            return
        }

        pcmBuffer.frameLength = frameCount

        let copyStatus = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frameCount),
            into: pcmBuffer.mutableAudioBufferList
        )

        guard copyStatus == noErr else { return }

        var sumSquares: Double = 0
        var peak: Float = 0
        var sampleCount = 0

        if let channels = pcmBuffer.floatChannelData {
            for channel in 0..<Int(pcmBuffer.format.channelCount) {
                for frame in 0..<Int(pcmBuffer.frameLength) {
                    let sample = channels[channel][frame]
                    sumSquares += Double(sample * sample)
                    peak = max(peak, abs(sample))
                    sampleCount += 1
                }
            }
        } else if let channels = pcmBuffer.int16ChannelData {
            for channel in 0..<Int(pcmBuffer.format.channelCount) {
                for frame in 0..<Int(pcmBuffer.frameLength) {
                    let sample = Float(channels[channel][frame]) / Float(Int16.max)
                    sumSquares += Double(sample * sample)
                    peak = max(peak, abs(sample))
                    sampleCount += 1
                }
            }
        }

        guard sampleCount > 0 else { return }

        let rms = sqrt(sumSquares / Double(sampleCount))
        let decibels = 20 * log10(max(rms, 0.00001))
        let normalizedLevel = CGFloat(max(0, min(1, (decibels + 60) / 60)))

        DispatchQueue.main.async {
            self.audioLevel = normalizedLevel
            self.isAudioClipping = peak >= 0.98
        }
    }
}
