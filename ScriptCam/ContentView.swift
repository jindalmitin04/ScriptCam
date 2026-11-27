import SwiftUI
import UniformTypeIdentifiers

enum RecordingAspectRatio: String, CaseIterable, Identifiable {
    case landscape = "16:9"
    case portrait = "9:16"
    case square = "1:1"
    case classic = "4:3"

    var id: String { rawValue }

    var value: CGFloat {
        switch self {
        case .landscape: return 16.0 / 9.0
        case .portrait: return 9.0 / 16.0
        case .square: return 1.0
        case .classic: return 4.0 / 3.0
        }
    }
}


enum RecordingFramingMode: String, CaseIterable, Identifiable {
    case crop = "Crop"
    case fit = "Fit"

    var id: String { rawValue }
}


enum ScriptPlacement: String, CaseIterable, Identifiable {
    case right = "Right"
    case left = "Left"
    case top = "Top"
    case bottom = "Bottom"

    var id: String { rawValue }
}

struct ContentView: View {
    @StateObject private var camera = CameraController()
    @State private var selectedAspectRatio: RecordingAspectRatio = .landscape
    @State private var selectedFramingMode: RecordingFramingMode = .crop
    @State private var selectedScriptPlacement: ScriptPlacement = .right
    @State private var countdownValue: Int? = nil
    @State private var countdownTimer: Timer? = nil
    @State private var script = """
    Paste or write your script here…

    Adjust text size and scroll speed using the Reading Tools on the right. Your script stays private and is never included in the recorded video.
    """
    @State private var isEditing = true
    @State private var autoScroll = false
    @State private var scrollSpeed = 18.0
    @State private var fontSize = 24.0
    @State private var scrollOffset: CGFloat = 0
    @State private var scriptContentHeight: CGFloat = 0
    @State private var scrollViewportHeight: CGFloat = 0

    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private func startRecordingCountdown() {
        guard countdownValue == nil, !camera.isRecording else { return }

        countdownValue = 3

        countdownTimer?.invalidate()

        countdownTimer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { _ in
            if let value = countdownValue, value > 1 {
                countdownValue = value - 1
            } else {
                countdownTimer?.invalidate()
                countdownTimer = nil
                countdownValue = nil

                camera.startRecording(
                    aspectRatio: selectedAspectRatio,
                    framingMode: selectedFramingMode
                )
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            layoutPicker

            mainPanels
                .padding(18)

            footer
        }
        .background(Color(red: 0.075, green: 0.082, blue: 0.10))
        .preferredColorScheme(.dark)
        .onAppear { camera.configure() }
        .onReceive(timer) { _ in
            guard autoScroll && !isEditing else { return }

            let maximumOffset = max(0, scriptContentHeight - scrollViewportHeight)

            if scrollOffset < maximumOffset {
                scrollOffset = min(
                    maximumOffset,
                    scrollOffset + CGFloat(scrollSpeed * 0.05)
                )
            } else {
                scrollOffset = maximumOffset
                autoScroll = false
            }
        }
    }

    private var layoutPicker: some View {
        HStack {
            Label("Script position", systemImage: "rectangle.split.2x1")

            Picker("", selection: $selectedScriptPlacement) {
                ForEach(ScriptPlacement.allCases) { placement in
                    Text(placement.rawValue).tag(placement)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var mainPanels: some View {
        switch selectedScriptPlacement {

        case .right:
            HStack(spacing: 16) {
                cameraPanel
                    .frame(minWidth: 480, maxWidth: .infinity)

                scriptPanel
                    .frame(width: 390)
            }

        case .left:
            HStack(spacing: 16) {
                scriptPanel
                    .frame(width: 390)

                cameraPanel
                    .frame(minWidth: 480, maxWidth: .infinity)
            }

        case .top:
            topStudioView

        case .bottom:
            VStack(spacing: 16) {
                cameraPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                scriptPanel
                    .frame(height: 260)
            }
        }
    }

    private var topStudioView: some View {
        HStack(alignment: .top, spacing: 16) {

            // LEFT: Camera and recording settings
            topCameraControls
                .frame(width: 210)

            // CENTRE: Teleprompter and camera preview
            VStack(spacing: 14) {
                topTeleprompterPanel

                topCameraPreviewPanel
                    .frame(maxWidth: .infinity)

                topRecordingControls
            }
            .frame(maxWidth: .infinity)

            // RIGHT: Reading and audio controls
            topReadingControls
                .frame(width: 210)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topCameraControls: some View {
        VStack(alignment: .leading, spacing: 16) {

            Label("RECORDING SETUP", systemImage: "camera")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Camera")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Camera", selection: $camera.selectedCameraID) {
                    ForEach(camera.availableCameras, id: \.uniqueID) { device in
                        Text(device.localizedName)
                            .tag(device.uniqueID)
                    }
                }
                .disabled(camera.isRecording || camera.availableCameras.isEmpty)
                .onChange(of: camera.selectedCameraID) { newID in
                    camera.selectCamera(id: newID)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Microphone")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Microphone", selection: $camera.selectedMicrophoneID) {
                    ForEach(camera.availableMicrophones, id: \.uniqueID) { device in
                        Text(device.localizedName)
                            .tag(device.uniqueID)
                    }
                }
                .disabled(camera.isRecording || camera.availableMicrophones.isEmpty)
                .onChange(of: camera.selectedMicrophoneID) { newID in
                    camera.selectMicrophone(id: newID)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text("Recording ratio")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Recording Ratio", selection: $selectedAspectRatio) {
                    ForEach(RecordingAspectRatio.allCases) { ratio in
                        Text(ratio.rawValue).tag(ratio)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Framing")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Framing", selection: $selectedFramingMode) {
                    ForEach(RecordingFramingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var topTeleprompterPanel: some View {
        scriptPanel
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .padding(14)
            .background(Color.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }


    private var topCameraPreviewPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("CAMERA PREVIEW")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                Spacer()

                Label("Private preview", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black)

                if camera.isConfigured {
                    CameraPreview(session: camera.session)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(camera.status)
                            .foregroundStyle(.secondary)
                    }
                }

                if let countdownValue = countdownValue {
                    Text("\(countdownValue)")
                        .font(.system(size: 100, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.7), radius: 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(selectedAspectRatio.value, contentMode: .fit)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    private var topRecordingControls: some View {
        VStack(spacing: 10) {

            HStack(spacing: 10) {
                if camera.isRecording {

                    Button {
                        if camera.isPaused {
                            camera.resumeRecording()
                        } else {
                            camera.pauseRecording()
                        }
                    } label: {
                        Label(
                            camera.isPaused ? "Resume" : "Pause",
                            systemImage: camera.isPaused ? "play.fill" : "pause.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button {
                        camera.stopRecording()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                } else {

                    Button {
                        if countdownValue != nil {
                            countdownTimer?.invalidate()
                            countdownTimer = nil
                            countdownValue = nil
                        } else {
                            startRecordingCountdown()
                        }
                    } label: {
                        Label(
                            countdownValue != nil ? "Cancel countdown" : "Start recording",
                            systemImage: countdownValue != nil ? "xmark.circle" : "record.circle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(!camera.isConfigured)
                }
            }

            if let url = camera.lastSavedURL {
                HStack {
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Button("Create MP4 copy") {
                        camera.exportMP4(from: url)
                    }
                    .buttonStyle(.bordered)
                    .disabled(camera.isRecording)
                }
            }

            if !camera.exportMessage.isEmpty {
                Text(camera.exportMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var topReadingControls: some View {
        VStack(alignment: .leading, spacing: 18) {

            Label("READING TOOLS", systemImage: "text.alignleft")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Text size")
                    Spacer()
                    Text("\(Int(fontSize)) pt")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.caption)

                Slider(value: $fontSize, in: 18...40, step: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Scroll speed")
                    Spacer()
                    Text("\(Int(scrollSpeed))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.caption)

                Slider(value: $scrollSpeed, in: 5...70, step: 1)
            }

            Divider()

            Text("AUDIO LEVEL")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))

                        Capsule()
                            .fill(camera.isAudioClipping ? Color.red : Color.green)
                            .frame(width: proxy.size.width * camera.audioLevel)
                    }
                }
                .frame(height: 9)
            }

            if camera.isAudioClipping {
                Label("Audio clipping", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Label("Microphone active", systemImage: "mic.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var header: some View {
        HStack {
            HStack(spacing: 9) {
                Image(systemName: "video.fill").foregroundStyle(.red)
                Text("ScriptCam").font(.system(size: 20, weight: .bold))
            }
            Spacer()
            Label(camera.status, systemImage: camera.isRecording ? "record.circle.fill" : "circle")
                .foregroundStyle(camera.isRecording ? .red : .secondary)
            Text(camera.elapsed).monospacedDigit().foregroundStyle(.white)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 15)
        .background(Color.black.opacity(0.28))
    }

    private var cameraPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CAMERA").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                Spacer()
                Label("Private preview", systemImage: "lock.fill").font(.caption).foregroundStyle(.secondary)
            }
            Picker("Recording Ratio", selection: $selectedAspectRatio) {
                ForEach(RecordingAspectRatio.allCases) { ratio in
                    Text(ratio.rawValue).tag(ratio)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Framing")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("Framing", selection: $selectedFramingMode) {
                    ForEach(RecordingFramingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("CAMERA")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Camera", selection: $camera.selectedCameraID) {
                        ForEach(camera.availableCameras, id: \.uniqueID) { device in
                            Text(device.localizedName)
                                .tag(device.uniqueID)
                        }
                    }
                    .disabled(camera.isRecording || camera.availableCameras.isEmpty)
                    .onChange(of: camera.selectedCameraID) { newID in
                        camera.selectCamera(id: newID)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("MICROPHONE")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Microphone", selection: $camera.selectedMicrophoneID) {
                        ForEach(camera.availableMicrophones, id: \.uniqueID) { device in
                            Text(device.localizedName)
                                .tag(device.uniqueID)
                        }
                    }
                    .disabled(camera.isRecording || camera.availableMicrophones.isEmpty)
                    .onChange(of: camera.selectedMicrophoneID) { newID in
                        camera.selectMicrophone(id: newID)
                    }
                }
            }
            HStack(spacing: 10) {
                Label("AUDIO", systemImage: "waveform")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))

                        Capsule()
                            .fill(camera.isAudioClipping ? Color.red : Color.green)
                            .frame(width: proxy.size.width * camera.audioLevel)
                    }
                }
                .frame(height: 8)

                if camera.isAudioClipping {
                    Text("CLIPPING")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.red)
                } else {
                    Text("LIVE")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 18)

            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color.black)
                if camera.isConfigured {
                    CameraPreview(session: camera.session)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(camera.status).foregroundStyle(.secondary)
                    }
                }

                if let countdownValue = countdownValue {
                    Text("\(countdownValue)")
                        .font(.system(size: 100, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.7), radius: 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .allowsHitTesting(false)
                }
            }
            .aspectRatio(selectedAspectRatio.value, contentMode: .fit)
            HStack(spacing: 10) {
                if camera.isRecording {
                    Button {
                        if camera.isPaused {
                            camera.resumeRecording()
                        } else {
                            camera.pauseRecording()
                        }
                    } label: {
                        Label(
                            camera.isPaused ? "Resume" : "Pause",
                            systemImage: camera.isPaused ? "play.fill" : "pause.fill"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button {
                        camera.stopRecording()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                } else {
                    Button {
                        if countdownValue != nil {
                            countdownTimer?.invalidate()
                            countdownTimer = nil
                            countdownValue = nil
                        } else {
                            startRecordingCountdown()
                        }
                    } label: {
                        Label(
                            countdownValue != nil ? "Cancel countdown" : "Start recording",
                            systemImage: countdownValue != nil ? "xmark.circle" : "record.circle"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(!camera.isConfigured)
                }
            }
            if let url = camera.lastSavedURL {
                VStack(alignment: .leading, spacing: 7) {
                    Text(url.lastPathComponent).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Button("Create MP4 copy") { camera.exportMP4(from: url) }
                        .buttonStyle(.bordered)
                        .disabled(camera.isRecording)
                }
            }
            if !camera.exportMessage.isEmpty {
                Text(camera.exportMessage).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
    }

    private var scriptPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YOUR SCRIPT").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                Spacer()
                Button(isEditing ? "Read mode" : "Edit script") {
                    isEditing.toggle()
                    autoScroll = false
                    scrollOffset = 0
                }
                .buttonStyle(.bordered)
            }

            if isEditing {
                TextEditor(text: $script)
                    .font(.system(size: 16))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color.white.opacity(0.055))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        Text(script)
                            .font(.system(size: fontSize, weight: .regular, design: .rounded))
                            .lineSpacing(9)
                            .foregroundStyle(.white.opacity(0.94))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .background(
                                GeometryReader { contentProxy in
                                    Color.clear.preference(
                                        key: ScriptHeightKey.self,
                                        value: contentProxy.size.height
                                    )
                                }
                            )
                            .offset(y: -scrollOffset)
                    }
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .topLeading
                    )
                    .clipped()
                    .onAppear {
                        scrollViewportHeight = proxy.size.height
                    }
                    .onChange(of: proxy.size.height) { newHeight in
                        scrollViewportHeight = newHeight
                    }
                    .onPreferenceChange(ScriptHeightKey.self) { newHeight in
                        scriptContentHeight = newHeight
                    }
                }
                .background(Color.white.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                Button(isEditing ? "Start reading" : (autoScroll ? "Pause scroll" : "Auto-scroll")) {
                    if isEditing {
                        isEditing = false
                        autoScroll = false
                        scrollOffset = 0
                    } else {
                        autoScroll.toggle()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                if !isEditing {
                    Button("Top") { scrollOffset = 0; autoScroll = false }
                        .buttonStyle(.bordered)
                }
            }

            if selectedScriptPlacement != .top {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Text size")
                        Spacer()
                        Text("\(Int(fontSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }.font(.caption)

                    Slider(value: $fontSize, in: 18...40, step: 1)

                    if !isEditing {
                        HStack {
                            Text("Scroll speed")
                            Spacer()
                            Text("\(Int(scrollSpeed))")
                                .foregroundStyle(.secondary)
                        }.font(.caption)

                        Slider(value: $scrollSpeed, in: 5...70, step: 1)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("The script stays on-screen only. Recordings contain camera video and microphone audio.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("V1 • Local recording").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.22))
    }
}

private struct ScriptHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
