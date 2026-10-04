# Chromivelle

<img src="docs/branding/icon.png" width="112" alt="Chromivelle icon" />

A Flutter photo editor with a dark Material 3 Expressive interface, device dynamic colors, and live GPU image adjustments. The current interface is in Chinese; Android is the tested platform.

## Features

- Import photos from the system photo picker; zoom, pan, and compare with the original.
- Seven tools: tone adjustments, black and white, selective color, geometry, white balance, HSL, and filters.
- Twenty filter recipes in a horizontally scrolling strip. Filter strength stays fixed on screen and carries over when switching recipes.
- Four editing tools fit across the bottom; swipe horizontally for the rest.
- Settings to enable individual tools, dynamic colors, and animations. Preferences persist across restarts.
- Rotation and horizontal/vertical mirroring, with color picking mapped back to the original image.
- Custom adaptive launcher icon and an Android themed monochrome icon.

## Run

Verified with Flutter 3.47.6 / Dart 3.13.5. Android minimum SDK: 24.

```sh
flutter pub get
flutter run
```

For checks and a debug APK:

```sh
flutter analyze
flutter test
flutter build apk --debug
```

## Current scope

This is an editing and preview prototype. Saving/exporting the edited image, cropping/perspective correction, undo/redo, and importing external LUT files are not implemented yet. Filter recipes update the base adjustment parameters; HSL, black-and-white, and selective-color settings remain independent.

The Android application ID remains `com.example.image_editor` to preserve compatibility with existing development installations. Release builds currently use the development signing configuration; configure a release key before distributing a production build.

## Project layout

- `lib/main.dart` — home screen, editor, tool panels, and state wiring.
- `lib/settings/` — persistent preferences and settings page.
- `lib/core/shader/` and `assets/shaders/` — preview transforms and GPU processing.
- `lib/data/model/` — editing parameters and filter recipes.
- `lib/ui/` — theme, motion, and Material Expressive adapter.
- `test/` — shader layouts, preview coordinates, settings, dynamic colors, and UI regression checks.
- `docs/branding/` — editable SVG and PNG of the app icon.
