import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/motion_tile.dart';
import 'editor_settings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static final _repository = Uri.parse('https://github.com/CLCTY/Chromivelle');

  Future<void> _openRepository(BuildContext context) async {
    try {
      if (await launchUrl(_repository, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // Offer the same fallback if the platform cannot handle the link.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('无法打开仓库，可以复制链接后访问'),
        action: SnackBarAction(
          label: '复制链接',
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: _repository.toString())),
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('设置保存失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    Widget section(String title, String? subtitle, List<Widget> children) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 6),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            Material(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(children: children),
            ),
          ],
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          PressMotion(
            child: TextButton(
              onPressed: () => _save(
                context,
                () => controller.update(const EditorSettings()),
              ),
              child: const Text('恢复默认'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          section('编辑工具', '启用的工具显示在编辑页底部，每屏 4 个，可左右滑动。关闭入口会保留照片已有的调整。', [
            for (final tool in EditorTool.values)
              SwitchListTile(
                key: ValueKey('setting-${tool.name}'),
                secondary: Icon(tool.icon, color: colors.secondary),
                title: Text(tool.label, style: const TextStyle(fontSize: 15)),
                subtitle: Text(
                  tool.description,
                  style: const TextStyle(fontSize: 11, height: 1.5),
                ),
                value: settings.enabledTools.contains(tool),
                onChanged:
                    settings.enabledTools.length == 1 &&
                        settings.enabledTools.contains(tool)
                    ? null
                    : (enabled) => _save(
                        context,
                        () => controller.setTool(tool, enabled),
                      ),
              ),
          ]),
          section('外观与交互', null, [
            SwitchListTile(
              key: const ValueKey('setting-dynamic'),
              secondary: const Icon(Icons.wallpaper_rounded),
              title: const Text('设备动态配色'),
              subtitle: const Text('使用系统壁纸与配色方案'),
              value: settings.dynamicColor,
              onChanged: (value) => _save(
                context,
                () => controller.update(settings.copyWith(dynamicColor: value)),
              ),
            ),
            SwitchListTile(
              key: const ValueKey('setting-motion'),
              secondary: const Icon(Icons.animation_rounded),
              title: const Text('界面动画'),
              subtitle: const Text('按压反馈与页面、工具切换过渡'),
              value: settings.animations,
              onChanged: (value) => _save(
                context,
                () => controller.update(settings.copyWith(animations: value)),
              ),
            ),
          ]),
          section('关于', null, [
            ListTile(
              key: const ValueKey('setting-repository'),
              leading: const Icon(Icons.code_rounded),
              title: const Text('GitHub 仓库'),
              subtitle: const Text('CLCTY/Chromivelle'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 20),
              onTap: () => _openRepository(context),
            ),
          ]),
        ],
      ),
    );
  }
}
