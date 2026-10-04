# 开发与发布 / Development and releases

## 项目结构 / Layout

| 路径 / Path | 内容 / Purpose |
| --- | --- |
| `lib/main.dart` | 主页、编辑页、工具面板 / Home, editor, tool panels |
| `lib/settings/` | 设置与本机持久化 / Settings and persistence |
| `lib/ui/` | 动态主题、按压动画与 M3E 适配 / Theme, motion, M3E adapter |
| `lib/core/shader/` | 实时预览、几何坐标转换 / Preview and coordinate transforms |
| `assets/shaders/` | GPU 图像处理 / GPU image processing |
| `lib/data/model/` | 参数模型与滤镜配方 / Parameters and filter recipes |
| `test/` | 布局、动态配色、设置、坐标、仓库链接及 shader 布局检查 / Regression tests |
| `docs/branding/` | 应用图标 SVG 与 PNG / Editable icon assets |

Android 应用 ID 为 `com.example.image_editor`，沿用现有开发安装。调试构建无需发布密钥。

The Android application ID is `com.example.image_editor`. Debug builds do not require a release key.

## 发布签名 / Release signing

每位开发者使用自己的私有签名文件。已有发布密钥时应继续使用同一份密钥，才能升级已安装的应用。不要将密钥或密码提交到 Git。

Use your own private signing key. Preserve the same key for future updates. Never commit signing files or passwords.

首次设置 / First-time setup:

```sh
mkdir -p android/keystore
keytool -genkeypair -v -keystore android/keystore/chromivelle-release.jks \
  -storetype JKS -keyalg RSA -keysize 3072 -validity 10000 -alias chromivelle
```

创建 `android/key.properties` / Create `android/key.properties`:

```properties
storeFile=keystore/chromivelle-release.jks
storePassword=YOUR_PRIVATE_PASSWORD
keyAlias=chromivelle
keyPassword=YOUR_PRIVATE_PASSWORD
```

这两个文件已被忽略。没有签名配置时，发布构建会明确报错；`flutter run` 与 debug 构建不受影响。

Both files are ignored by Git. A release build requires the signing configuration; debug builds remain available without it.

```sh
flutter build apk --release
```

产物 / Output: `build/app/outputs/flutter-apk/app-release.apk`.

## 依赖与权利 / Dependencies and rights

依赖清单与精确版本见 `pubspec.yaml` 和 `pubspec.lock`。第三方组件保留各自的许可证；本项目尚未指定开源许可证。

Dependencies and pinned versions are recorded in `pubspec.yaml` and `pubspec.lock`. Third-party packages retain their own licenses. This project has not yet specified an open-source license.
