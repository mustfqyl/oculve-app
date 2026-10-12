import 'package:flutter/material.dart' hide Text;
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:oculve/core/localization/localized_text.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.centerTitle = true,
    this.actions,
    this.leading,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;

    // On macOS, the window controls (close, minimize, maximize) are on the top left.
    // To avoid overlapping, we add top padding to push the AppBar down slightly.
    final bool isMacOs = !kIsWeb && Platform.isMacOS;
    final double topPadding = isMacOs
        ? 32.0
        : 0.0; // 32 is roughly the height of macOS window controls

    Widget? actualLeading = leading;
    if (actualLeading == null && Navigator.canPop(context)) {
      actualLeading = IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: fg, size: 20),
        onPressed: () => Navigator.pop(context),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: AppBar(
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: actualLeading,
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: centerTitle ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            height: 1.12,
          ),
        ),
        centerTitle: centerTitle,
        actions: actions,
        bottom: bottom,
      ),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
