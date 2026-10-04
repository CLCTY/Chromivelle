<div align="center">
  <img src="docs/branding/icon.png" width="112" alt="Chromivelle icon" />
  <h1>Chromivelle</h1>
  <p>An Android photo editor with Material 3 Expressive</p>
  <p>
    <a href="https://github.com/CLCTY/Chromivelle/releases"><img src="https://img.shields.io/github/v/release/CLCTY/Chromivelle?include_prereleases&label=release&color=8c80cc" alt="Release" /></a>
    <img src="https://img.shields.io/badge/Android-7.0%2B-8ab6a2" alt="Android 7.0+" />
    <img src="https://img.shields.io/badge/Flutter-Material%203%20Expressive-7c9ecb" alt="Flutter" />
  </p>
  <p><a href="README.md">简体中文</a> · <b>English</b></p>
  <p><a href="https://github.com/CLCTY/Chromivelle/releases">Download</a> · <a href="#features">Features</a> · <a href="https://github.com/CLCTY/Chromivelle/issues">Report an issue</a></p>
</div>

## About

Chromivelle is a Flutter photo editor for Android with a dark Material 3 Expressive interface, device dynamic colors, and live GPU previews.

**v0.1.0 is a preview release. Image adjustments, live previews, and PNG saving to the gallery are available.**

## Download and use

Download `Chromivelle-v0.1.0-android.apk` from [Releases](https://github.com/CLCTY/Chromivelle/releases).

- Android 7.0 (API 24) or newer; the APK includes ARM64 and ARMv7.
- Dynamic colors require Android 12+ and system support. Other devices use the built-in dark palette.
- Four tools fit across the bottom. Swipe horizontally for more.
- Swipe through twenty filter recipes. The strength slider stays fixed and retains its value when switching recipes.
- Tap Save in the editor to write a PNG to `Pictures/Chromivelle`, leaving the original untouched.
- Manage tool visibility, dynamic colors, and animations in Settings; open the GitHub repository from the About section.
- Release and development APKs use different signing certificates. If Android reports a conflict, uninstall the development build first. Uninstalling clears app preferences, so record any settings you need.

## Features

| Tool | Available adjustments |
| --- | --- |
| Tone | Brightness, contrast, saturation, hue, exposure, highlights, and shadows |
| Black and white | Grayscale conversion and color-channel controls |
| Selective color | Pick a color from the image; preserve or remove a selected color |
| Geometry | Rotation and horizontal/vertical mirroring |
| White balance | Temperature and tint |
| HSL | Hue, saturation, and luminance for six color ranges |
| Filters | Twenty recipes including Original, with adjustable strength |

Zoom, pan, compare with the original, and use adaptive and monochrome launcher icons. Preferences persist locally; image processing runs on the device.

## Release scope

v0.1.0 supports importing, editing, previewing, and saving. Cropping/perspective correction, undo/redo, and external LUT import are still pending.

Saved images are rendered from the original source as lossless PNGs. Unusually large images are capped at approximately 24 megapixels and an 8192-pixel longest edge to bound mobile memory usage. Original EXIF metadata is not copied.

Recipes replace base tone adjustments while preserving black-and-white, selective-color, and HSL settings. The app interface is currently in Chinese. Basic editing flows have been checked on a physical Android device.

## Development

Verified with Flutter 3.47.6 / Dart 3.13.5.

```sh
git clone https://github.com/CLCTY/Chromivelle.git
cd Chromivelle
flutter pub get
flutter run
```

```sh
flutter analyze
flutter test
flutter build apk --debug
```

See [development and signing notes](docs/DEVELOPMENT.md) for project layout and release setup.

## Feedback

Open an [issue](https://github.com/CLCTY/Chromivelle/issues) with your device, Android version, and reproduction steps. Check screenshots for personal content before posting.
