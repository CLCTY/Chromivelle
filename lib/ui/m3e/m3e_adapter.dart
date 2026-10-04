// Material Expressive components used by the app.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_expressive/material_expressive.dart' as m3e;

/// M3E 多边形形状。包的形状 API 收 `List<Offset>`(归一化到 0..1 的顶点)。
abstract final class M3eShapes {
  const M3eShapes._();

  /// 正多边形(圆角处理后即为 M3E 的"有机"形状)
  static List<Offset> polygon(int sides, {double rotationDeg = -90}) {
    final step = 2 * math.pi / sides;
    final rot = rotationDeg * math.pi / 180;
    return List<Offset>.generate(sides, (i) {
      final a = rot + step * i;
      return Offset(0.5 + 0.5 * math.cos(a), 0.5 + 0.5 * math.sin(a));
    }, growable: false);
  }

  static final List<Offset> circle = polygon(24);
  static final List<Offset> square = polygon(4, rotationDeg: 45);
  static final List<Offset> triangle = polygon(3);
  static final List<Offset> pentagon = polygon(5);
  static final List<Offset> hexagon = polygon(6);
  static final List<Offset> diamond = polygon(4);

  /// 四角方形(不旋转),用于卡片/容器
  static final List<Offset> roundedSquare = polygon(4);
}

/// M3E 适配层。UI 代码只依赖这个类。
abstract final class M3e {
  const M3e._();

  // ==========================================================================
  // 主题
  // ==========================================================================

  /// 生成 M3E 亮色主题。
  /// [shapeType] organic=有机形状(图片 App 首选)/ rounded / angular / expressive
  /// [vibrancy] 0=标准 M3, 0.3=非常鲜艳
  static ThemeData theme({
    required Color seedColor,
    m3e.ExpressiveShapeType shapeType = m3e.ExpressiveShapeType.organic,
    double vibrancy = 0.2,
  }) {
    final expressive = m3e.ExpressiveTheme.fromSeed(
      seedColor: seedColor,
      shapeType: shapeType,
      vibrancy: vibrancy,
    );
    return m3e.ExpressiveComponentThemes.applyExpressive(
      expressive.materialTheme,
    );
  }

  /// 生成 M3E 暗色主题。
  static ThemeData darkTheme({
    required Color seedColor,
    m3e.ExpressiveShapeType shapeType = m3e.ExpressiveShapeType.organic,
    double vibrancy = 0.2,
  }) {
    final expressive = m3e.ExpressiveTheme.fromSeed(
      seedColor: seedColor,
      shapeType: shapeType,
      vibrancy: vibrancy,
      vibrantDarkMode: true,
    );
    return m3e.ExpressiveComponentThemes.applyExpressive(
      expressive.materialDarkTheme,
    );
  }

  /// 把已有 ThemeData 升级成 M3E 组件主题。
  /// 用于接入动态取色(dynamic_color)场景:保留用户的壁纸配色,只加 M3E 组件样式。
  static ThemeData applyExpressive(ThemeData base) {
    return m3e.ExpressiveComponentThemes.applyExpressive(base);
  }

  /// 生成完整的 M3E 主题对(亮+暗)
  static ({ThemeData light, ThemeData dark}) themePair({
    required Color seedColor,
    m3e.ExpressiveShapeType shapeType = m3e.ExpressiveShapeType.organic,
  }) {
    return (
      light: theme(seedColor: seedColor, shapeType: shapeType),
      dark: darkTheme(seedColor: seedColor, shapeType: shapeType),
    );
  }

  // ==========================================================================
  // 加载指示器
  // ==========================================================================

  /// M3E 分段弧形加载指示器。图片解码/导出等待。
  static Widget containedLoading({
    Key? key,
    double size = 48,
    int segments = 4,
  }) {
    return m3e.ContainedLoadingIndicator(
      key: key,
      size: size,
      segments: segments,
    );
  }

  /// 波浪线性进度条(带确定进度)。导出百分比。
  static Widget wavyLinear({Key? key, double? value}) {
    return m3e.WavyLinearProgressIndicator(key: key, value: value);
  }

  /// 波浪圆形进度条(带确定进度)。
  static Widget wavyCircular({Key? key, double? value}) {
    return m3e.WavyCircularProgressIndicator(key: key, value: value);
  }

  // ==========================================================================
  // 形状与状态变形
  // ==========================================================================

  /// 状态切换时的容器形状变形。
  /// 用于:滤镜选中态、工具栏按钮激活态、色彩通道选中态。
  static Widget stateMorph({
    required bool isActive,
    required Widget child,
    List<Offset>? activeShape,
    List<Offset>? inactiveShape,
    Color? activeColor,
    Color? inactiveColor,
    double size = 56,
    Duration duration = const Duration(milliseconds: 400),
    Key? key,
  }) {
    return m3e.StateMorphContainer(
      key: key,
      isActive: isActive,
      activeShape: activeShape ?? M3eShapes.circle,
      inactiveShape: inactiveShape ?? M3eShapes.roundedSquare,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      size: size,
      duration: duration,
      child: child,
    );
  }

  /// 容器展开/收起变形(FAB -> 全屏编辑器的经典转场)。
  static Widget shapeTransform({
    required Widget Function(BuildContext, VoidCallback) closedBuilder,
    required Widget Function(BuildContext, VoidCallback) openBuilder,
    List<Offset>? closedShape,
    double closedSize = 56,
    Duration duration = const Duration(milliseconds: 500),
    Key? key,
  }) {
    return m3e.ShapeContainerTransform(
      key: key,
      closedShape: closedShape ?? M3eShapes.circle,
      closedSize: closedSize,
      closedBuilder: closedBuilder,
      openBuilder: openBuilder,
      duration: duration,
    );
  }

  // ==========================================================================
  // 按钮组与工具栏
  // ==========================================================================

  /// M3E 按钮组(单选)。调色模式切换、黑白通道选择用它。
  ///
  /// ExpressiveButtonGroup 是**单选**语义(buttons + selectedIndex + onSelected),
  /// 不是任意 children 的容器。
  static Widget buttonGroup({
    required List<String> labels,
    List<IconData?>? icons,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
    Key? key,
  }) {
    return m3e.ExpressiveButtonGroup(
      key: key,
      selectedIndex: selectedIndex,
      onSelected: onSelected,
      buttons: [
        for (var i = 0; i < labels.length; i++)
          m3e.ExpressiveButtonGroupItem(
            label: labels[i],
            icon: (icons != null && i < icons.length) ? icons[i] : null,
          ),
      ],
    );
  }

  /// 浮动工具栏。图片编辑器底部操作条。
  static Widget floatingToolbar({
    required List<m3e.FloatingToolbarItem> items,
    double elevation = 6,
    Key? key,
  }) {
    return m3e.ExpressiveFloatingToolbar(
      key: key,
      items: items,
      elevation: elevation,
    );
  }

  /// 便捷方法:从图标列表构造工具栏
  static Widget iconToolbar({
    required List<IconData> icons,
    required List<String?> tooltips,
    required List<VoidCallback?> onPressed,
    Key? key,
  }) {
    return m3e.ExpressiveFloatingToolbar(
      key: key,
      items: [
        for (var i = 0; i < icons.length; i++)
          m3e.FloatingToolbarItem(
            icon: icons[i],
            tooltip: (i < tooltips.length) ? tooltips[i] : null,
            onPressed: (i < onPressed.length) ? onPressed[i] : null,
          ),
      ],
    );
  }

  // ==========================================================================
  // 浮层
  // ==========================================================================

  /// M3E 对话框。用于丢弃确认等破坏性操作。
  static Future<T?> dialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return m3e.showExpressiveDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
    );
  }

  /// M3E Snackbar。撤销/导出成功提示。
  static void snackBar(
    BuildContext context, {
    required String message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    m3e.showExpressiveSnackBar(
      context,
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }
}
