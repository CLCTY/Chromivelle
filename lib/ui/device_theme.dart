import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

/// Reload the OS palette after returning from wallpaper/theme settings.
class DeviceTheme extends StatefulWidget {
  const DeviceTheme({super.key, required this.builder});
  final Widget Function(ColorScheme? light, ColorScheme? dark) builder;

  @override
  State<DeviceTheme> createState() => _DeviceThemeState();
}

class _DeviceThemeState extends State<DeviceTheme> with WidgetsBindingObserver {
  final _paletteKey = GlobalKey<DynamicColorBuilderState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _paletteKey.currentState?.initPlatformState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      DynamicColorBuilder(key: _paletteKey, builder: widget.builder);
}
