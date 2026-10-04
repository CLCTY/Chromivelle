// Load and cache compiled fragment programs before opening the editor.

import 'dart:async';
import 'dart:ui' show FragmentProgram;

/// 已知的 shader 资源路径,与 pubspec.yaml 的 shaders: 声明严格对应。
abstract final class ShaderAssets {
  static const String adjust = 'assets/shaders/adjust.frag';
  static const String selectiveColor = 'assets/shaders/selective_color.frag';
  static const String lut3d = 'assets/shaders/lut3d.frag';
}

/// Shader 加载器。启动时 [preload] 一次,之后 [get] 同步返回。
class ShaderRegistry {
  ShaderRegistry._();

  static final ShaderRegistry instance = ShaderRegistry._();

  final Map<String, FragmentProgram> _programs = {};
  final Map<String, Future<FragmentProgram>> _loading = {};

  /// 是否已完成预热
  bool get isReady => _programs.isNotEmpty;

  /// 启动预热。并发加载全部 shader。
  Future<void> preload() async {
    await Future.wait([
      _load(ShaderAssets.adjust),
      _load(ShaderAssets.selectiveColor),
      _load(ShaderAssets.lut3d),
    ]);
  }

  Future<FragmentProgram> _load(String assetPath) {
    final cached = _programs[assetPath];
    if (cached != null) return Future.value(cached);

    return _loading.putIfAbsent(assetPath, () async {
      final program = await FragmentProgram.fromAsset(assetPath);
      _programs[assetPath] = program;
      _loading.remove(assetPath);
      return program;
    });
  }

  /// 同步获取。必须先 [preload],否则抛异常。
  ///
  /// 为什么是同步:每次 paint 都可能触发,await 会让渲染抖动。
  FragmentProgram get(String assetPath) {
    final program = _programs[assetPath];
    if (program == null) {
      throw StateError(
        'Shader "$assetPath" 未预热。请在 main() 里 await ShaderRegistry.instance.preload()。',
      );
    }
    return program;
  }

  FragmentProgram get adjust => get(ShaderAssets.adjust);
  FragmentProgram get selectiveColor => get(ShaderAssets.selectiveColor);
  FragmentProgram get lut3d => get(ShaderAssets.lut3d);
}
