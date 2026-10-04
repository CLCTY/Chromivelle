// Application entry, editor state, and editing screens.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'core/shader/image_preview.dart';
import 'core/shader/image_exporter.dart';
import 'core/shader/shader_registry.dart';
import 'data/model/edit_command.dart';
import 'ui/m3e/m3e_adapter.dart';
import 'ui/motion_tile.dart';
import 'ui/device_theme.dart';
import 'settings/editor_settings.dart';
import 'settings/settings_page.dart';
import 'data/model/look_preset.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 预热 shader。放在 runApp 前,避免首帧闪烁。
  await ShaderRegistry.instance.preload();

  EditorSettings settings;
  try {
    settings = await LocalSettingsStore().load();
  } catch (_) {
    settings = const EditorSettings();
  }
  runApp(
    ProviderScope(
      overrides: [initialSettingsProvider.overrideWithValue(settings)],
      child: const ImageEditorApp(),
    ),
  );
}

// =============================================================================
// 状态
// =============================================================================

/// 当前图片与调整参数。
///
/// 用 Riverpod 3的 Notifier(不是已废弃的 StateNotifier)。
class EditorController extends Notifier<EditorState> {
  @override
  EditorState build() => const EditorState();

  void setAdjust(AdjustParams p) =>
      state = state.copyWith(edit: state.edit.copyWith(adjust: p));

  void setSelective(SelectiveColorParams p) =>
      state = state.copyWith(edit: state.edit.copyWith(selectiveColor: p));

  void setGeometry(GeometryTransform g) =>
      state = state.copyWith(edit: state.edit.copyWith(geometry: g));

  /// 替换图片(加载完成时)
  void setImage(ui.Image? image, {String? sourcePath}) => state = EditorState(
    image: image,
    sourcePath: sourcePath,
    edit: state.edit,
    isLoading: state.isLoading,
  );

  /// 切换加载态
  void setLoading(bool loading) => state = state.copyWith(isLoading: loading);

  void reset() => state = state.copyWith(edit: const EditState());

  /// 从图片像素取色 -> 得到目标色相
  void applyPickedColor(Color c) {
    final hsv = HSVColor.fromColor(c);
    state = state.copyWith(
      edit: state.edit.copyWith(
        selectiveColor: state.edit.selectiveColor.copyWith(
          enabled: true,
          targetHue: hsv.hue / 360.0,
        ),
      ),
    );
  }
}

class EditorState {
  const EditorState({
    this.image,
    this.sourcePath,
    this.edit = const EditState(),
    this.isLoading = false,
  });

  final ui.Image? image;
  final String? sourcePath;
  final EditState edit;
  final bool isLoading;

  EditorState copyWith({ui.Image? image, EditState? edit, bool? isLoading}) {
    return EditorState(
      image: image ?? this.image,
      sourcePath: sourcePath,
      edit: edit ?? this.edit,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final editorProvider = NotifierProvider<EditorController, EditorState>(
  EditorController.new,
);

// =============================================================================
// App
// =============================================================================

class ImageEditorApp extends ConsumerWidget {
  const ImageEditorApp({super.key});

  // Only used on platforms without system dynamic color.
  static const Color _seed = Color(0xFF64748B);

  static final _buttonStyle = ButtonStyle(
    animationDuration: const Duration(milliseconds: 180),
    shape: WidgetStateProperty.resolveWith(
      (states) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          states.contains(WidgetState.pressed) ? 6 : 12,
        ),
      ),
    ),
  );

  static ThemeData _polish(ThemeData theme) => theme.copyWith(
    filledButtonTheme: FilledButtonThemeData(style: _buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonStyle),
    textButtonTheme: TextButtonThemeData(style: _buttonStyle),
    iconButtonTheme: IconButtonThemeData(style: _buttonStyle),
    chipTheme: theme.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    splashFactory: InkRipple.splashFactory,
    scaffoldBackgroundColor: theme.colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return DeviceTheme(
      builder: (lightDynamic, darkDynamic) {
        final light = !settings.dynamicColor || lightDynamic == null
            ? M3e.theme(seedColor: _seed)
            : M3e.applyExpressive(
                ThemeData(useMaterial3: true, colorScheme: lightDynamic),
              );
        final dark = !settings.dynamicColor || darkDynamic == null
            ? M3e.darkTheme(seedColor: _seed)
            : M3e.applyExpressive(
                ThemeData(useMaterial3: true, colorScheme: darkDynamic),
              );
        return MaterialApp(
          title: 'Chromivelle',
          debugShowCheckedModeBanner: false,
          theme: _polish(light),
          darkTheme: _polish(dark),
          themeMode: ThemeMode.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations:
                  MediaQuery.disableAnimationsOf(context) ||
                  !settings.animations,
            ),
            child: child!,
          ),
          home: const EditorPage(),
        );
      },
    );
  }
}

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final ImagePicker _picker = ImagePicker();
  int _panelIndex = 0;
  int _adjustIndex = 0;
  bool _comparing = false;
  bool _pickingColor = false;

  final ScrollController _toolScroll = ScrollController();
  HslZone _zone = HslZone.red;
  int? _lookIndex;
  double _lookStrength = 1;
  bool _isSaving = false;
  final _tools = EditorTool.values;

  @override
  void dispose() {
    _toolScroll.dispose();
    super.dispose();
  }

  static const _adjustments = [
    (label: '亮度', icon: Icons.brightness_6_outlined),
    (label: '对比度', icon: Icons.contrast_rounded),
    (label: '饱和度', icon: Icons.palette_outlined),
    (label: '色相', icon: Icons.color_lens_outlined),
    (label: '曝光', icon: Icons.light_mode_outlined),
    (label: '色温', icon: Icons.thermostat_rounded),
    (label: '高光', icon: Icons.wb_sunny_outlined),
    (label: '阴影', icon: Icons.nights_stay_outlined),
  ];

  Duration get _motionDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 280);

  Widget _transition(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .035),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );

  ColorScheme get _colors => Theme.of(context).colorScheme;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(editorProvider);
    final tools = ref.watch(settingsProvider).visibleTools;
    if (!tools.any((tool) => tool.index == _panelIndex)) {
      _panelIndex = tools.first.index;
      _pickingColor = false;
    }
    return PopScope(
      canPop: s.image == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !s.isLoading) _goHome();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: s.image == null
              ? null
              : PressMotion(
                  child: IconButton(
                    tooltip: '返回主页',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _goHome,
                  ),
                ),
          title: Row(
            children: [
              if (s.image == null)
                Icon(
                  Icons.auto_awesome_rounded,
                  color: _colors.primary,
                  size: 22,
                ),
              if (s.image == null) const SizedBox(width: 9),
              Flexible(
                child: Text(
                  s.image == null ? 'Chromivelle' : '编辑照片',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            if (s.image != null)
              PressMotion(
                child: IconButton.filledTonal(
                  key: const ValueKey('save-image'),
                  tooltip: '保存到相册',
                  onPressed: s.isLoading ? null : _saveImage,
                  icon: const Icon(Icons.save_outlined),
                ),
              ),
            PressMotion(
              child: IconButton(
                tooltip: '设置',
                icon: const Icon(Icons.settings_outlined),
                onPressed: _openSettings,
              ),
            ),
            if (s.image != null)
              PopupMenuButton<String>(
                tooltip: '更多操作',
                onSelected: (action) {
                  if (action == 'pick') _pickImage(context);
                  if (action == 'reset') {
                    ref.read(editorProvider.notifier).reset();
                    setState(() => _lookIndex = null);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'pick', child: Text('更换照片')),
                  PopupMenuItem(
                    value: 'reset',
                    enabled: !s.edit.isNeutral,
                    child: const Text('重置所有调整'),
                  ),
                ],
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              AnimatedSwitcher(
                duration: _motionDuration,
                reverseDuration: _motionDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                transitionBuilder: _transition,
                child: s.image == null
                    ? KeyedSubtree(
                        key: const ValueKey('home'),
                        child: _buildWelcome(s),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('editor'),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final panel = _buildPanel(s);
                            final preview = _buildPreviewArea(s);
                            if (constraints.maxWidth > constraints.maxHeight &&
                                constraints.maxWidth > 600) {
                              return Row(
                                children: [
                                  Expanded(child: preview),
                                  SizedBox(width: 330, child: panel),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                Expanded(child: preview),
                                SizedBox(
                                  height: (constraints.maxHeight * .44).clamp(
                                    240.0,
                                    340.0,
                                  ),
                                  child: panel,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
              if (s.isLoading)
                Positioned.fill(
                  child: ColoredBox(
                    color: _colors.surface.withValues(alpha: .85),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          M3e.containedLoading(),
                          const SizedBox(height: 16),
                          Text(_isSaving ? '正在保存到相册…' : '正在准备照片…'),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome(EditorState s) => LayoutBuilder(
    builder: (context, box) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '开始编辑照片',
                  style: TextStyle(
                    fontSize: 32,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: _colors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '从相册选择图片，调整光影和色彩。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: _colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  height: 210,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _colors.primaryContainer,
                        _colors.tertiaryContainer,
                      ],
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        right: 18,
                        top: 18,
                        child: Icon(
                          Icons.auto_awesome,
                          size: 32,
                          color: _colors.primary.withValues(alpha: .5),
                        ),
                      ),
                      Transform.rotate(
                        angle: -.12,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: _colors.surface,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: _colors.primary.withValues(alpha: .12),
                                blurRadius: 25,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.landscape_rounded,
                            size: 110,
                            color: _colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: PressMotion(
                    child: FilledButton.icon(
                      onPressed: s.isLoading ? null : () => _pickImage(context),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text(
                        '从相册导入',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    '在本机编辑，原照片保持不变',
                    style: TextStyle(
                      fontSize: 12,
                      color: _colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    for (
                      var i = 0;
                      i <
                          ref
                              .watch(settingsProvider)
                              .visibleTools
                              .take(3)
                              .length;
                      i++
                    ) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: MotionTile(
                          color: _colors.surfaceContainerLow,
                          borderColor: _colors.outlineVariant.withValues(
                            alpha: .3,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          onTap: () {
                            setState(
                              () => _panelIndex = ref
                                  .read(settingsProvider)
                                  .visibleTools[i]
                                  .index,
                            );
                            _pickImage(context);
                          },
                          child: Column(
                            children: [
                              Icon(
                                ref
                                    .watch(settingsProvider)
                                    .visibleTools[i]
                                    .icon,
                                color: _colors.primary,
                              ),
                              const SizedBox(height: 9),
                              Text(
                                ref
                                    .watch(settingsProvider)
                                    .visibleTools[i]
                                    .label,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _buildPreviewArea(EditorState s) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: ImagePreview(
              image: s.image!,
              state: _comparing ? const EditState() : s.edit,
              onPixelTapped: _pickingColor && !_comparing
                  ? (pixel) => _pickColorAt(s, pixel)
                  : null,
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _previewBadge(
              _comparing ? '原图' : '${s.image!.width} × ${s.image!.height}',
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Semantics(
              label: '长按查看原图',
              button: true,
              child: Tooltip(
                message: '长按查看原图',
                child: AnimatedScale(
                  scale: _comparing ? .92 : 1,
                  duration: _motionDuration,
                  curve: Curves.easeOutCubic,
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _comparing = true),
                    onTapUp: (_) => setState(() => _comparing = false),
                    onTapCancel: () => setState(() => _comparing = false),
                    child: AnimatedContainer(
                      duration: _motionDuration,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _comparing
                            ? _colors.primaryContainer
                            : Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.compare_rounded,
                        color: _comparing
                            ? _colors.onPrimaryContainer
                            : Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: _previewBadge(
                _pickingColor ? '点击照片，选择要保留的颜色' : '双指缩放 · 双击复位 · 长按右上角对比',
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _previewBadge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 10),
    ),
  );

  Widget _buildPanel(EditorState s) => Container(
    decoration: BoxDecoration(
      color: _colors.surfaceContainerLow,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
    ),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Column(
      children: [
        Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: _colors.outlineVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              _tools[_panelIndex].label == '留色'
                  ? '去色留色'
                  : _tools[_panelIndex].label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              s.edit.isNeutral ? '原始照片' : '已调整',
              style: TextStyle(fontSize: 11, color: _colors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: AnimatedSwitcher(
              duration: _motionDuration,
              transitionBuilder: _transition,
              child: KeyedSubtree(
                key: ValueKey(_panelIndex),
                child: _buildPanelContent(s),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (ref.watch(settingsProvider).visibleTools.length > 4)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swipe_rounded,
                  size: 13,
                  color: _colors.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  '左右滑动 · ${ref.watch(settingsProvider).visibleTools.length} 个工具',
                  style: TextStyle(
                    fontSize: 10,
                    color: _colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 72,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tools = ref.watch(settingsProvider).visibleTools;
              final width =
                  constraints.maxWidth / (tools.length < 4 ? tools.length : 4);
              return ListView.builder(
                key: const PageStorageKey('editor-tool-bar'),
                controller: _toolScroll,
                scrollDirection: Axis.horizontal,
                itemExtent: width,
                itemCount: tools.length,
                itemBuilder: (context, index) {
                  final tool = tools[index];
                  final selected = _panelIndex == tool.index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: MotionTile(
                      key: ValueKey('tool-${tool.name}'),
                      selected: selected,
                      color: selected
                          ? _colors.primaryContainer
                          : Colors.transparent,
                      borderColor: selected
                          ? _colors.primary.withValues(alpha: .35)
                          : Colors.transparent,
                      onTap: () => setState(() {
                        _panelIndex = tool.index;
                        _pickingColor = false;
                      }),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: selected ? 1.08 : 1,
                            duration: _motionDuration,
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              tool.icon,
                              size: 23,
                              color: selected
                                  ? _colors.onPrimaryContainer
                                  : _colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tool.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _buildPanelContent(EditorState s) {
    final ctrl = ref.read(editorProvider.notifier);
    final a = s.edit.adjust;
    switch (_panelIndex) {
      case 0:
        final values = [
          a.brightness,
          a.contrast,
          a.saturation,
          a.hue,
          a.exposure,
          a.temperature,
          a.highlights,
          a.shadows,
        ];
        void update(double v) {
          setState(() => _lookIndex = null);
          ctrl.setAdjust(switch (_adjustIndex) {
            0 => a.copyWith(brightness: v),
            1 => a.copyWith(contrast: v),
            2 => a.copyWith(saturation: v),
            3 => a.copyWith(hue: v),
            4 => a.copyWith(exposure: v),
            5 => a.copyWith(temperature: v),
            6 => a.copyWith(highlights: v),
            _ => a.copyWith(shadows: v),
          });
        }
        final range = _adjustIndex == 4
            ? 2.0
            : _adjustIndex == 3
            ? .5
            : 1.0;
        return ListView(
          children: [
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _adjustments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => MotionTile(
                  selected: _adjustIndex == i,
                  width: 64,
                  color: _adjustIndex == i
                      ? _colors.secondaryContainer
                      : _colors.surfaceContainer,
                  borderColor: _adjustIndex == i
                      ? _colors.primary.withValues(alpha: .5)
                      : _colors.outlineVariant.withValues(alpha: .25),
                  onTap: () => setState(() => _adjustIndex = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        scale: _adjustIndex == i ? 1.12 : 1,
                        duration: _motionDuration,
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          _adjustments[i].icon,
                          size: 23,
                          color: _adjustIndex == i
                              ? _colors.onSecondaryContainer
                              : _colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _adjustments[i].label,
                        style: const TextStyle(fontSize: 11),
                      ),
                      if (values[i] != 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: _motionDuration,
              transitionBuilder: _transition,
              child: KeyedSubtree(
                key: ValueKey(_adjustIndex),
                child: _slider(
                  _adjustments[_adjustIndex].label,
                  values[_adjustIndex],
                  -range,
                  range,
                  update,
                  neutral: 0,
                ),
              ),
            ),
          ],
        );
      case 1:
        return ListView(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('开启黑白', style: TextStyle(fontSize: 14)),
              value: a.enableBW,
              onChanged: (v) => ctrl.setAdjust(a.copyWith(enableBW: v)),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var i = 0; i < 6; i++)
                  PressMotion(
                    child: ChoiceChip(
                      label: Text(['自然', '红通道', '黄通道', '绿通道', '青通道', '蓝通道'][i]),
                      selected: a.enableBW && a.bwChannel == i,
                      onSelected: (_) => ctrl.setAdjust(
                        a.copyWith(
                          enableBW: true,
                          bwChannel: i,
                          bwWeights: AdjustParams.bwPresets[i]!,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      case 2:
        final sc = s.edit.selectiveColor;
        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sc.enabled ? '只保留选中的颜色' : '让喜欢的颜色成为主角',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Switch(
                  value: sc.enabled,
                  onChanged: (v) => ctrl.setSelective(sc.copyWith(enabled: v)),
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: HSVColor.fromAHSV(
                      1,
                      sc.targetHue * 360,
                      .8,
                      .85,
                    ).toColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PressMotion(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _pickingColor = !_pickingColor),
                      icon: Icon(
                        _pickingColor ? Icons.close : Icons.colorize,
                        size: 17,
                      ),
                      label: Text(_pickingColor ? '取消取色' : '从照片取色'),
                    ),
                  ),
                ),
              ],
            ),
            _slider(
              '色相容差',
              sc.hueTolerance,
              .01,
              .3,
              (v) => ctrl.setSelective(sc.copyWith(hueTolerance: v)),
            ),
            _slider(
              '边缘柔和',
              sc.softness,
              .01,
              .3,
              (v) => ctrl.setSelective(sc.copyWith(softness: v)),
            ),
            _slider(
              '保留饱和',
              sc.keepSaturation,
              0,
              1,
              (v) => ctrl.setSelective(sc.copyWith(keepSaturation: v)),
            ),
            _slider(
              '压暗程度',
              sc.blackStrength,
              0,
              1,
              (v) => ctrl.setSelective(sc.copyWith(blackStrength: v)),
            ),
          ],
        );
      case 4:
        return ListView(
          children: [
            Text(
              '调整冷暖与色偏',
              style: TextStyle(fontSize: 12, color: _colors.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            _slider(
              '色温 · 冷 / 暖',
              a.temperature,
              -1,
              1,
              (v) => ctrl.setAdjust(a.copyWith(temperature: v)),
              neutral: 0,
            ),
            _slider(
              '色调 · 绿 / 洋红',
              a.tint,
              -1,
              1,
              (v) => ctrl.setAdjust(a.copyWith(tint: v)),
              neutral: 0,
            ),
          ],
        );
      case 5:
        final zone = a.hslZones[_zone] ?? HslAdjustment.neutral;
        void update(HslAdjustment value) => ctrl.setAdjust(
          a.copyWith(enableHSL: true, hslZones: {...a.hslZones, _zone: value}),
        );
        return ListView(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('分区调色', style: TextStyle(fontSize: 14)),
              value: a.enableHSL,
              onChanged: (value) =>
                  ctrl.setAdjust(a.copyWith(enableHSL: value)),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final item in HslZone.values)
                  PressMotion(
                    child: ChoiceChip(
                      label: Text(['红', '黄', '绿', '青', '蓝', '洋红'][item.index]),
                      selected: _zone == item,
                      onSelected: (_) => setState(() => _zone = item),
                    ),
                  ),
              ],
            ),
            _slider(
              '色相',
              zone.hue,
              -.5,
              .5,
              (v) => update(zone.copyWith(hue: v)),
              neutral: 0,
            ),
            _slider(
              '饱和度',
              zone.saturation,
              -1,
              1,
              (v) => update(zone.copyWith(saturation: v)),
              neutral: 0,
            ),
            _slider(
              '明度',
              zone.luminance,
              -1,
              1,
              (v) => update(zone.copyWith(luminance: v)),
              neutral: 0,
            ),
          ],
        );
      case 6:
        final hasFilter = _lookIndex != null && _lookIndex != 0;
        return Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '20 种配方 · 左右滑动选择',
                style: TextStyle(fontSize: 11, color: _colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                key: const PageStorageKey('look-strip'),
                scrollDirection: Axis.horizontal,
                itemExtent: 96,
                itemCount: LookPreset.all.length,
                itemBuilder: (context, i) => Center(
                  child: SizedBox(
                    width: 88,
                    height: 44,
                    child: MotionTile(
                      key: ValueKey('look-$i'),
                      selected: _lookIndex == i,
                      color: _lookIndex == i
                          ? _colors.secondaryContainer
                          : _colors.surfaceContainer,
                      borderColor: _lookIndex == i
                          ? _colors.secondary
                          : _colors.outlineVariant,
                      onTap: () {
                        setState(() => _lookIndex = i);
                        ctrl.setAdjust(
                          LookPreset.all[i].atStrength(_lookStrength, a),
                        );
                      },
                      child: Center(
                        child: Text(
                          LookPreset.all[i].name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _lookIndex == i
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: _lookIndex == i
                                ? _colors.onSecondaryContainer
                                : _colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _slider(
              '滤镜强度',
              hasFilter ? _lookStrength : 0,
              0,
              1,
              hasFilter
                  ? (v) {
                      setState(() => _lookStrength = v);
                      ctrl.setAdjust(
                        LookPreset.all[_lookIndex!].atStrength(v, a),
                      );
                    }
                  : null,
            ),
          ],
        );
      default:
        final g = s.edit.geometry;
        return ListView(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PressMotion(
                  child: OutlinedButton.icon(
                    onPressed: () => ctrl.setGeometry(g.rotateQuarter(false)),
                    icon: const Icon(Icons.rotate_90_degrees_ccw),
                    label: const Text('左转 90°'),
                  ),
                ),
                PressMotion(
                  child: OutlinedButton.icon(
                    onPressed: () => ctrl.setGeometry(g.rotateQuarter(true)),
                    icon: const Icon(Icons.rotate_90_degrees_cw),
                    label: const Text('右转 90°'),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('水平翻转', style: TextStyle(fontSize: 14)),
              value: g.flipHorizontal,
              onChanged: (v) => ctrl.setGeometry(g.copyWith(flipHorizontal: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('垂直翻转', style: TextStyle(fontSize: 14)),
              value: g.flipVertical,
              onChanged: (v) => ctrl.setGeometry(g.copyWith(flipVertical: v)),
            ),
          ],
        );
    }
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double>? onChanged, {
    double? neutral,
  }) => Column(
    children: [
      Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const Spacer(),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _colors.primary,
            ),
          ),
          if (neutral != null)
            SizedBox(
              height: 30,
              width: 34,
              child: PressMotion(
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: '重置$label',
                  icon: const Icon(Icons.restart_alt, size: 17),
                  onPressed: value == neutral || onChanged == null
                      ? null
                      : () => onChanged(neutral),
                ),
              ),
            ),
        ],
      ),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        label: value.toStringAsFixed(2),
        onChanged: onChanged,
        semanticFormatterCallback: (v) => '$label ${v.toStringAsFixed(2)}',
      ),
    ],
  );

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: _motionDuration,
        reverseTransitionDuration: _motionDuration,
        pageBuilder: (context, animation, secondary) => const SettingsPage(),
        transitionsBuilder: (context, animation, secondary, child) =>
            _transition(child, animation),
      ),
    );
  }

  Future<void> _goHome() async {
    final state = ref.read(editorProvider);
    if (state.isLoading) return;
    if (!state.edit.isNeutral) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('返回主页？'),
          content: const Text('本次调整将被清除，原照片不会改变。'),
          actions: [
            PressMotion(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('继续编辑'),
              ),
            ),
            PressMotion(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('返回主页'),
              ),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    ref.read(editorProvider.notifier).setImage(null);
    setState(() {
      _panelIndex = 0;
      _adjustIndex = 0;
      _pickingColor = false;
      _comparing = false;
    });
  }

  Future<void> _pickImage(BuildContext context) async {
    if (ref.read(editorProvider).isLoading) return;
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await _loadImage(file);
  }

  Future<void> _loadImage(XFile file) async {
    final ctrl = ref.read(editorProvider.notifier);
    ctrl.setLoading(true);
    setState(() {
      _comparing = false;
      _pickingColor = false;
    });

    try {
      final bytes = await file.readAsBytes();
      // 限制预览大小；保存时重新读取原始图片。
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 2048,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      ctrl.reset();
      setState(() {
        _lookIndex = null;
        _lookStrength = 1;
      });
      ctrl.setImage(frame.image, sourcePath: file.path);
      codec.dispose();
    } catch (e) {
      if (!mounted) return;
      M3e.snackBar(
        context,
        message: '图片加载失败，请重新选择图片',
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) ctrl.setLoading(false);
    }
  }

  Future<void> _saveImage() async {
    final snapshot = ref.read(editorProvider);
    if (snapshot.image == null || snapshot.isLoading) return;
    final ctrl = ref.read(editorProvider.notifier);
    setState(() => _isSaving = true);
    ctrl.setLoading(true);
    try {
      final result = await ImageExporter.render(
        preview: snapshot.image!,
        sourcePath: snapshot.sourcePath,
        state: snapshot.edit,
      );
      await ImageExporter.saveToGallery(result);
      if (!mounted) return;
      M3e.snackBar(
        context,
        message:
            '已保存到相册 · ${result.width} × ${result.height} · Pictures/Chromivelle',
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      M3e.snackBar(
        context,
        message: '保存失败，请检查存储空间与权限后重试',
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        ctrl.setLoading(false);
      }
    }
  }

  /// 取色:从 ui.Image 读像素 -> HSV 色相
  Future<void> _pickColorAt(EditorState s, Offset pixel) async {
    final image = s.image;
    if (image == null) return;

    // toByteData 是异步的(Future),必须 await
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null || !mounted) return;

    final x = pixel.dx.floor().clamp(0, image.width - 1);
    final y = pixel.dy.floor().clamp(0, image.height - 1);
    final offset = (y * image.width + x) * 4;
    final data = byteData.buffer.asUint8List();

    final c = Color.fromARGB(
      data[offset + 3],
      data[offset],
      data[offset + 1],
      data[offset + 2],
    );
    if (!mounted) return;
    ref.read(editorProvider.notifier).applyPickedColor(c);
    setState(() {
      _panelIndex = 2;
      _pickingColor = false;
    });
  }
}
