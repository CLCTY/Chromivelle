<div align="center">
  <img src="docs/branding/icon.png" width="112" alt="Chromivelle 图标" />
  <h1>Chromivelle</h1>
  <p>采用 Material 3 Expressive 的 Android 图片编辑器</p>
  <p>
    <a href="https://github.com/CLCTY/Chromivelle/releases"><img src="https://img.shields.io/github/v/release/CLCTY/Chromivelle?include_prereleases&label=版本&color=8c80cc" alt="版本" /></a>
    <img src="https://img.shields.io/badge/Android-7.0%2B-8ab6a2" alt="Android 7.0+" />
    <img src="https://img.shields.io/badge/Flutter-Material%203%20Expressive-7c9ecb" alt="Flutter" />
  </p>
  <p><b>简体中文</b> · <a href="README.en.md">English</a></p>
  <p><a href="https://github.com/CLCTY/Chromivelle/releases">下载应用</a> · <a href="#功能">功能介绍</a> · <a href="https://github.com/CLCTY/Chromivelle/issues">问题反馈</a></p>
</div>

## 简介

Chromivelle 是一款基于 Flutter 的 Android 图片编辑器，采用深色 Material 3 Expressive 界面、设备动态配色和 GPU 实时预览。

**当前版本为 v0.1.0 预览版。已支持图片调整、实时预览与 PNG 保存到相册。**

## 下载与使用

前往 [Releases](https://github.com/CLCTY/Chromivelle/releases) 下载 `Chromivelle-v0.1.0-android.apk`，安装后从相册导入照片即可开始调整。

- 支持 Android 7.0（API 24）及以上，安装包包含 ARM64 和 ARMv7。
- 设备动态取色需要 Android 12 及以上且系统支持；其他设备使用内置深色配色。
- 编辑界面底部每屏展示 4 个工具，左右滑动查看其余工具。
- 滤镜横向滑动选择，强度条固定在下方，切换滤镜保留强度。
- 编辑完成后点击右上角“保存”，PNG 图片会写入相册的 `Pictures/Chromivelle`，原照片保持不变。
- 设置页可管理工具入口、动态配色与动画，并直接访问 GitHub 仓库。
- 正式签名的安装包与此前的调试版签名不同；若安装提示冲突，需先卸载调试版。卸载会清除应用设置，请先记录需要保留的设置。

## 功能

| 工具 | 已支持的调整 |
| --- | --- |
| 调色 | 亮度、对比度、饱和度、色相、曝光、高光与阴影 |
| 黑白 | 黑白转换与颜色通道控制 |
| 留色 | 从图片取色，保留或去除指定颜色 |
| 变换 | 旋转、水平翻转、垂直翻转 |
| 白平衡 | 色温与色调 |
| 分色 | 六个色彩范围的色相、饱和度与明度调整 |
| 滤镜 | 包含原色在内的 20 种配方，以及可调强度 |

还支持图片缩放、拖动、原图对比、自定义自适应图标和 Android 主题图标。工具开关与外观偏好会保存在本机。图片处理在设备上进行。

## 版本进度

v0.1.0 提供完整的导入、调整、预览和保存流程。裁剪与透视矫正、撤销/重做、外部 LUT 导入尚未实现。

保存使用原始图片重新渲染，输出无损 PNG。超大图片会限制在约 2400 万像素、最长边 8192 像素以内，避免移动设备内存耗尽。导出不保留原图 EXIF 元数据。

滤镜会更新基础调色参数；黑白、留色和分色设置独立保留。目前界面语言为中文，已在 Android 真机上验证基础编辑流程。

## 开发

已验证环境：Flutter 3.47.6 / Dart 3.13.5。

```sh
git clone https://github.com/CLCTY/Chromivelle.git
cd Chromivelle
flutter pub get
flutter run
```

检查与调试构建：

```sh
flutter analyze
flutter test
flutter build apk --debug
```

项目结构、发布签名与构建说明见 [开发文档](docs/DEVELOPMENT.md)。

## 反馈

遇到问题或有功能建议，请提交 [Issue](https://github.com/CLCTY/Chromivelle/issues)，附上设备型号、Android 版本与复现步骤。提交截图前请检查是否包含私人照片或个人信息。
