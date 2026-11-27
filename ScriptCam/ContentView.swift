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
    @State private var selectedScriptPlacement: ScriptPlacement = .right
    @State private var script = "Paste or write your script here…\\n\\nUse the controls below to adjust the reading experience. The script is displayed in this app only and is never included in the recorded video."
    @State private var isEditing = true
    @State private var autoScroll = false
    @State private var scrollSpeed = 18.0
    @State private var fontSize = 24.0
    @State private var scrollOffset: CGFloat = 0

    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

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
            if autoScroll && !isEditing {
                scrollOffset += CGFloat(scrollSpeed * 0.05)
            }
        }
    }

    private var layoutPicker: some View {
        HStack {
            Label("Script position", systemImage: "rectangle.split.2x1")

            Picker("Script position", selection: $selectedScriptPlacement) {
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
            VStack(spacing: 16) {
                scriptPanel
                    .frame(height: 260)

                cameraPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .bottom:
            VStack(spacing: 16) {
                cameraPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                scriptPanel
                    .frame(height: 260)
            }
        }
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
            }
            .aspectRatio(selectedAspectRatio.value, contentMode: .fit)
            HStack(spacing: 10) {
                Button {
                    camera.isRecording ? camera.stopRecording() : camera.startRecording()
                } label: {
                    Label(camera.isRecording ? "Stop recording" : "Start recording",
                          systemImage: camera.isRecording ? "stop.fill" : "record.circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                .tint(camera.isRecording ? .red : .blue)
                .disabled(!camera.isConfigured)
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
                    ScrollViewReader { reader in
                        ScrollView {
                            Text(script)
                                .font(.system(size: fontSize, weight: .regular, design: .rounded))
                                .lineSpacing(9)
                                .foregroundStyle(.white.opacity(0.94))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .id("scriptText")
                                .background(GeometryReader { geo in
                                    Color.clear.preference(key: ScriptHeightKey.self,
                                                           value: geo.frame(in: .named("scriptScroll")).height)
                                })
                        }
                        .coordinateSpace(name: "scriptScroll")
                        .onChange(of: scrollOffset) { _ in
                            if autoScroll {
                                reader.scrollTo("scriptText", anchor: UnitPoint(x: 0.5, y: min(1, scrollOffset / max(1, proxy.size.height * 10)))
                                )
                            }
                        }
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

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Text size")
                    Spacer()
                    Text("\\(Int(fontSize)) pt").monospacedDigit().foregroundStyle(.secondary)
                }.font(.caption)
                Slider(value: $fontSize, in: 18...40, step: 1)
                if !isEditing {
                    HStack {
                        Text("Scroll speed")
                        Spacer()
                        Text("\\(Int(scrollSpeed))").foregroundStyle(.secondary)
                    }.font(.caption)
                    Slider(value: $scrollSpeed, in: 5...70, step: 1)
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
