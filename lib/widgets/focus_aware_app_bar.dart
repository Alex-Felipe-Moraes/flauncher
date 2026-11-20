import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_service.dart';
import 'date_time_widget.dart';

class FocusAwareAppBar extends StatefulWidget implements PreferredSizeWidget {
  static const double toolbarHeight = kToolbarHeight + 20;

  final bool gallerySelected;
  final ValueChanged<bool> onPageSelected;

  const FocusAwareAppBar({
    super.key,
    required this.gallerySelected,
    required this.onPageSelected,
  });

  @override
  State<StatefulWidget> createState() {
    return _FocusAwareAppBarState();
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);
}

class _FocusAwareAppBarState extends State<FocusAwareAppBar> {
  bool focused = false;
  bool _settingsFocused = false;

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsService, bool>(
        selector: (_, settings) => settings.autoHideAppBarEnabled,
        builder: (context, autoHide, widget) {
          if (autoHide) {
            return Focus(
                canRequestFocus: false,
                child: AnimatedContainer(
                    curve: Curves.decelerate,
                    duration: Duration(milliseconds: 250),
                    height: focused ? FocusAwareAppBar.toolbarHeight : 0,
                    child: widget!),
                onFocusChange: (hasFocus) {
                  this.setState(() {
                    focused = hasFocus;
                  });
                });
          }

          return widget!;
        },
        child: AppBar(
          toolbarHeight: FocusAwareAppBar.toolbarHeight,
          titleSpacing: 24,
          title: Transform.translate(
            offset: const Offset(0, 15), // positivo desce; negativo sobe
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavigationTab(
                  label: 'Início',
                  selected: !widget.gallerySelected,
                  onPressed: () => widget.onPageSelected(false),
                ),
                const SizedBox(width: 8),
                _NavigationTab(
                  label: 'Todos os Apps',
                  selected: widget.gallerySelected,
                  onPressed: () => widget.onPageSelected(true),
                ),
              ],
            ),
          ),
          actions: [
            Transform.translate(
              offset: const Offset(0, 15),
              child: Focus(
                onFocusChange: (hasFocus) {
                  setState(() => _settingsFocused = hasFocus);
                },
                child: IconButton(
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                  icon: AnimatedScale(
                    scale: _settingsFocused ? 1.35 : 1,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: const Icon(
                      Icons.settings_outlined,
                      color: Color.fromARGB(255, 255, 255, 255),
                      shadows: [
                        Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 2))
                      ],
                    ),
                  ),
                  onPressed: () => showDialog(
                      context: context, builder: (_) => const SettingsPanel()),
                  focusColor: Colors.transparent,
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, 15), // positivo desce
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 32),
                child: Selector<
                    SettingsService,
                    ({
                      bool showDateInStatusBar,
                      bool showTimeInStatusBar,
                      String dateFormat,
                      String timeFormat
                    })>(
                  selector: (context, service) => (
                    showDateInStatusBar: service.showDateInStatusBar,
                    showTimeInStatusBar: service.showTimeInStatusBar,
                    dateFormat: service.dateFormat,
                    timeFormat: service.timeFormat
                  ),
                  builder: (context, dateTimeSettings, _) {
                    // TODO: Disabling the "show date" option while both are enabled causes the *time* to disappear,
                    // then re-enabling that same option causes the time to appear twice.
                    // A restart (or just changing to the full screen clock) fixes the issue, but why does this happen?
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      if (dateTimeSettings.showDateInStatusBar)
                        Flexible(
                            child: DateTimeWidget(
                          dateTimeSettings.dateFormat,
                          updateInterval: const Duration(minutes: 1),
                          textStyle:
                              Theme.of(context).textTheme.titleLarge!.copyWith(
                            shadows: [
                              const Shadow(
                                  color: Colors.black54,
                                  offset: Offset(0, 2),
                                  blurRadius: 8)
                            ],
                          ),
                        )),
                      if (dateTimeSettings.showDateInStatusBar &&
                          dateTimeSettings.showTimeInStatusBar)
                        const SizedBox(width: 16),
                      if (dateTimeSettings.showTimeInStatusBar)
                        Flexible(
                            child: DateTimeWidget(dateTimeSettings.timeFormat,
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .titleLarge!
                                    .copyWith(
                                  shadows: [
                                    const Shadow(
                                        color: Colors.black54,
                                        offset: Offset(0, 2),
                                        blurRadius: 8)
                                  ],
                                )))
                    ]);
                  },
                ),
              ),
            ),
          ],
        ));
  }
}

class _NavigationTab extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _NavigationTab({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  State<_NavigationTab> createState() => _NavigationTabState();
}

class _NavigationTabState extends State<_NavigationTab> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: widget.selected || _focusNode.hasFocus
          ? FontWeight.w600
          : FontWeight.w400,
      shadows: const [
        Shadow(color: Colors.black54, blurRadius: 8),
      ],
    );
    final titleScale = _focusNode.hasFocus
        ? 1.14
        : widget.selected
            ? 1.08
            : 1.0;
    final textPainter = TextPainter(
      text: TextSpan(text: widget.label, style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    return TextButton(
      focusNode: _focusNode,
      onPressed: widget.onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const RoundedRectangleBorder(),
        overlayColor: Colors.transparent,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: titleScale,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Text(widget.label, style: titleStyle),
          ),
          const SizedBox(height: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 2.5,
            width: widget.selected
                ? textPainter.width *
                    titleScale *
                    (widget.label == 'Todos os Apps' ? 0.48 : 0.6)
                : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
              boxShadow: _focusNode.hasFocus
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
