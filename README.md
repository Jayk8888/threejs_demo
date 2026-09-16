# Three.js Robot Demo

A Flutter application that embeds a Three.js scene in an in-app WebView. It loads the animated `RobotExpressive` glTF model and provides native Flutter controls for selecting an animation and posing the robot's head.

## Features

- Interactive Three.js scene with orbit camera controls, lighting, grid, and ground plane.
- Animated RobotExpressive glTF model, loaded from the official Three.js examples site.
- Animation picker populated from the model at runtime.
- X, Y, and Z inputs to set the robot head orientation while the **Still** animation is selected.

## Requirements

- Flutter SDK compatible with Dart `>=3.0.0 <4.0.0`
- A device or emulator with WebView support
- Internet access while the app runs, since Three.js modules and the robot model are fetched from CDNs.

## Run locally

```bash
flutter pub get
flutter run
```

To list available targets first, run:

```bash
flutter devices
```

## How it works

The Flutter UI is defined in `lib/main.dart`. It uses `flutter_inappwebview` to render an inline HTML document. The document imports Three.js, `GLTFLoader`, and `OrbitControls`; after the model has loaded, it sends its animation names back to Flutter through a JavaScript handler. Flutter then invokes JavaScript functions to switch animations or update the head pose.

## Project structure

```text
lib/main.dart          Flutter UI and embedded Three.js scene
assets/threejs/        Local experiment assets (not used by the current inline scene)
pubspec.yaml           Flutter dependencies and SDK constraints
```

## Notes

- The inline scene currently fetches the model from `threejs.org`; the bundled `assets/threejs/RobotExpressive.glb` is not the source used at runtime.
- Head orientation and spin behavior only apply when the **Still** animation is active.
