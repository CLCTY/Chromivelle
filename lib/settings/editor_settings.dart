import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EditorTool {
  adjust('调色', Icons.tune_rounded, '亮度、对比度、饱和度与光影调整'),
  blackWhite('黑白', Icons.tonality_rounded, '黑白转换与六种通道配方'),
  selective('留色', Icons.colorize_rounded, '取色并保留选中颜色'),
  geometry('变换', Icons.crop_rotate_rounded, '旋转、水平翻转与垂直翻转'),
  whiteBalance('白平衡', Icons.thermostat_rounded, '冷暖色温与绿 / 洋红色调'),
  hsl('分色', Icons.palette_outlined, '分别调整六个颜色区域'),
  looks('滤镜', Icons.auto_awesome_outlined, '一键应用调色配方并调节强度');

  const EditorTool(this.label, this.icon, this.description);
  final String label;
  final IconData icon;
  final String description;
}

class EditorSettings {
  const EditorSettings({
    this.enabledTools = const {
      EditorTool.adjust,
      EditorTool.blackWhite,
      EditorTool.selective,
      EditorTool.geometry,
      EditorTool.whiteBalance,
      EditorTool.hsl,
      EditorTool.looks,
    },
    this.dynamicColor = true,
    this.animations = true,
  });

  final Set<EditorTool> enabledTools;
  final bool dynamicColor;
  final bool animations;
  List<EditorTool> get visibleTools =>
      EditorTool.values.where(enabledTools.contains).toList();

  EditorSettings copyWith({
    Set<EditorTool>? enabledTools,
    bool? dynamicColor,
    bool? animations,
  }) => EditorSettings(
    enabledTools: enabledTools == null
        ? this.enabledTools
        : Set.unmodifiable(enabledTools),
    dynamicColor: dynamicColor ?? this.dynamicColor,
    animations: animations ?? this.animations,
  );

  String encode() => jsonEncode({
    'tools': enabledTools.map((tool) => tool.name).toList(),
    'dynamicColor': dynamicColor,
    'animations': animations,
  });

  static EditorSettings decode(String? value) {
    if (value == null) return const EditorSettings();
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      final names = (json['tools'] as List).cast<String>().toSet();
      final tools = EditorTool.values
          .where((tool) => names.contains(tool.name))
          .toSet();
      return EditorSettings(
        enabledTools: tools.isEmpty
            ? const {EditorTool.adjust}
            : Set.unmodifiable(tools),
        dynamicColor: json['dynamicColor'] as bool? ?? true,
        animations: json['animations'] as bool? ?? true,
      );
    } catch (_) {
      return const EditorSettings();
    }
  }
}

abstract interface class SettingsStore {
  Future<EditorSettings> load();
  Future<void> save(EditorSettings settings);
}

class LocalSettingsStore implements SettingsStore {
  final _prefs = SharedPreferencesAsync();
  static const _key = 'image_editor.settings.v1';
  @override
  Future<EditorSettings> load() async =>
      EditorSettings.decode(await _prefs.getString(_key));
  @override
  Future<void> save(EditorSettings settings) =>
      _prefs.setString(_key, settings.encode());
}

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => LocalSettingsStore(),
);
final initialSettingsProvider = Provider<EditorSettings>(
  (ref) => const EditorSettings(),
);
final settingsProvider = NotifierProvider<SettingsController, EditorSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<EditorSettings> {
  Future<void> _pending = Future.value();
  @override
  EditorSettings build() => ref.read(initialSettingsProvider);

  Future<void> update(EditorSettings settings) {
    final previous = state;
    state = settings;
    final store = ref.read(settingsStoreProvider);
    final saved = _pending.then((_) => store.save(settings));
    _pending = saved.catchError((Object error) {});
    return saved.catchError((Object error) {
      if (ref.mounted && identical(state, settings)) state = previous;
      throw error;
    });
  }

  Future<void> setTool(EditorTool tool, bool enabled) {
    final tools = {...state.enabledTools};
    if (enabled) {
      tools.add(tool);
    } else {
      tools.remove(tool);
    }
    if (tools.isEmpty) throw StateError('至少保留一个编辑工具');
    return update(state.copyWith(enabledTools: tools));
  }
}
