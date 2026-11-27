# ScriptCam V1

A small native macOS SwiftUI app for recording from the MacBook webcam while reading a private script in a separate panel.

## V1 features

- Built-in webcam preview using AVFoundation.
- Microphone audio capture.
- Save the original recording as MOV.
- Create an MP4 copy after recording.
- Script editor and distraction-free reading mode.
- Manual scrolling with the trackpad/mouse.
- Adjustable automatic scrolling speed.
- Adjustable script font size.
- Dark interface.
- Script text is not part of the camera recording.

## Requirements

- macOS 13 or later.
- Xcode 15 or later.
- Apple Silicon or Intel Mac.
- XcodeGen (`brew install xcodegen`).

## Generate and open the Xcode project

From Terminal:

```bash
cd /path/to/ScriptCam
brew install xcodegen
xcodegen generate
open ScriptCam.xcodeproj
```

In Xcode, select the `ScriptCam` scheme and your Mac as the destination, then press **Run**.

The first launch asks for Camera and Microphone access. Allow both in System Settings → Privacy & Security if prompted.

## Build a DMG

From Terminal:

```bash
cd /path/to/ScriptCam
chmod +x Scripts/build_dmg.sh
./Scripts/build_dmg.sh
```

The installer will be created at:

```text
build/ScriptCam.dmg
```

Open the DMG and drag ScriptCam into Applications.

## Important notes

- The project is currently unsigned. On your own Mac, macOS may show a warning the first time. Use Finder → Applications → ScriptCam → right-click → Open, then confirm.
- For distribution to other people, sign the app with a Developer ID certificate and notarize it with Apple.
- MOV is the primary camera recording format. MP4 is generated as a separate export after recording.
- V1 is intentionally local-only: it does not upload scripts or recordings.
- Keep the script window visible beside the camera preview. Do not use macOS screen recording for this workflow; the app records directly from the camera and microphone using AVFoundation.

## Troubleshooting

### Black camera preview
Check System Settings → Privacy & Security → Camera and enable ScriptCam. Quit and reopen the app.

### No audio
Check System Settings → Privacy & Security → Microphone and enable ScriptCam. Also verify the selected Mac input device in System Settings → Sound → Input.

### MP4 export fails
The MOV file remains available. MP4 export uses Apple's AVFoundation export session and depends on the codec/container combination supported by the Mac.
