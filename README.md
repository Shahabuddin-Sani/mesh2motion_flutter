# Mesh2Motion Flutter

A Flutter port of [ComfyUI-mesh2motion](https://github.com/jtydhr88/ComfyUI-mesh2motion), the 3D character rigging and animation editor, rebuilt as a standalone cross-platform app using [macbear_3d](https://github.com/macbearchen/macbear_3d) (OpenGL ES via Google ANGLE).

---

## ✨ Features

| Feature | Details |
|---|---|
| **3D Viewport** | Full OpenGL ES rendering via macbear_3d / ANGLE |
| **Model Loading** | GLB, glTF, OBJ file import via native file picker |
| **Skeleton Types** | Human, Quadruped, Bird, Dragon – each with full bone hierarchy |
| **Bone Hierarchy** | Collapsible tree view with click-to-select |
| **Bone Gizmos** | 3D sphere overlays highlighting each bone in the viewport |
| **Animation Library** | Pre-built animations per skeleton type, grouped by category |
| **Timeline** | Scrubable playback bar with play/pause, speed control (0.25×–3×) |
| **Transform Tools** | Select / Move / Rotate / Scale toolbar |
| **Wireframe Mode** | Toggle wireframe overlay on the loaded mesh |
| **Export GLB** | Export rigged and animated models to GLB |
| **Properties Panel** | Bone transforms (position/rotation/scale), animation info |
| **Viewport HUD** | Axis gizmo, active tool indicator, bone label tooltip |

---

## 🗂️ Project Structure

```
mesh2motion_flutter/
├── lib/
│   ├── main.dart                    # App entry + macbear_3d engine init
│   ├── theme/
│   │   └── app_theme.dart           # Dark industrial color palette
│   ├── models/
│   │   └── editor_state.dart        # Riverpod state + animation library data
│   ├── services/
│   │   └── mesh2motion_scene.dart   # macbear_3d M3Scene subclass
│   ├── screens/
│   │   └── editor_screen.dart       # Root screen – 3-column layout
│   └── widgets/
│       ├── top_toolbar.dart         # Menu bar + transform tools
│       ├── left_panel.dart          # Skeleton selector + bone tree
│       ├── right_panel.dart         # Animation library + properties
│       ├── bottom_timeline.dart     # Playback timeline
│       ├── viewport_overlay.dart    # HUD overlays (gizmo, stats, hints)
│       └── busy_overlay.dart        # Loading spinner overlay
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml      # OpenGL ES + file permissions
├── ios/
│   └── Runner/
│       └── Info.plist               # iOS permissions + embedded views
└── pubspec.yaml
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter ≥ 3.22 (stable channel)
- Dart ≥ 3.3
- Android: minSdkVersion 21 (Android 5.0+), OpenGL ES 3.0 device
- iOS: iOS 13+, Metal-capable device

### Installation

```bash
# 1. Clone
git clone <this-repo>
cd mesh2motion_flutter

# 2. Get dependencies (pulls macbear_3d from GitHub)
flutter pub get

# 3. Run
flutter run                     # default device
flutter run -d android          # Android
flutter run -d ios              # iOS
flutter run -d macos            # macOS desktop
flutter run -d windows          # Windows desktop
```

### Android Setup

In `android/app/build.gradle`, ensure:

```groovy
android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

### iOS Setup

Open `ios/Runner.xcworkspace` in Xcode:
1. Set Deployment Target to iOS 13.0+
2. Under **Signing & Capabilities**, add your team
3. Run on device (ANGLE/OpenGL ES requires real hardware)

---

## 🏗️ Architecture

### State Management (Riverpod)

```
EditorState (immutable)
  ├── EditorPhase        empty → modelLoaded → skeletonFitted → animated → exported
  ├── SkeletonType       human | quadruped | bird | dragon
  ├── List<BoneInfo>     bone hierarchy for the selected skeleton
  ├── AnimationEntry?    currently active animation
  ├── EditorTool         select | move | rotate | scale
  └── playback controls  isPlaying, animPlaybackSpeed, animProgress

EditorNotifier (StateNotifier) — owns all mutations
```

### 3D Rendering (macbear_3d)

`Mesh2MotionScene` extends `M3Scene` and handles:

- **Camera** – `M3OrbitCamera` with pan/orbit/zoom gestures
- **Lighting** – directional sun + fill + ambient
- **Model** – loaded via `M3GltfLoader`, auto-scaled to fit viewport
- **Bone gizmos** – `M3Mesh(M3SphereGeom)` entities placed at heuristic bone positions
- **Animation** – delegates to `M3Entity.animationSpeed` for skinned mesh playback
- **Wireframe** – `M3Entity.wireframe` toggle

The `M3View` widget from macbear_3d provides the OpenGL ES canvas.

---

## 🎨 Design

**Aesthetic**: Industrial dark with amber accents — matches the technical, creative nature of 3D rigging tools like Blender and Maya.

| Token | Value | Use |
|---|---|---|
| `bgPrimary` | `#0D0F14` | App background |
| `bgSecondary` | `#161A22` | Toolbar, tab bars |
| `bgPanel` | `#1C2130` | Side panels |
| `accent` | `#E8A020` | Active states, progress |
| `boneColor` | `#64D8CB` | Bone gizmos |
| `boneSelected` | `#00E5CC` | Selected bone highlight |

---

## 🔄 Comparison with ComfyUI-mesh2motion

| ComfyUI-mesh2motion | This Flutter App |
|---|---|
| TypeScript + Vue 3 + Three.js | Dart + Flutter + macbear_3d |
| Embedded iframe in ComfyUI | Standalone cross-platform app |
| PostMessage API to ComfyUI | Riverpod state (self-contained) |
| Mesh2Motion web editor | Native OpenGL ES via macbear_3d |
| Node context menu integration | File picker for model loading |
| ComfyUI GLB node output | Direct file export |

---

## 📦 Dependencies

| Package | Purpose |
|---|---|
| `macbear_3d` | 3D rendering engine (OpenGL ES via ANGLE) |
| `flutter_riverpod` | State management |
| `file_picker` | Native file dialogs for model import/export |
| `vector_math` | 3D vector/matrix math |
| `path_provider` | Platform file paths |
| `permission_handler` | Runtime permissions (Android) |

---

## 📄 License

MIT — see original [ComfyUI-mesh2motion](https://github.com/jtydhr88/ComfyUI-mesh2motion) and [macbear_3d](https://github.com/macbearchen/macbear_3d) for their respective licenses.
