import 'package:flutter/material.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_route.dart';
import '../../home/presentation/home_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // Very short delay for the loading screen as requested
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(appRoute(const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;
    final logo = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: fg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Icon(
          Icons.lock,
          size: 36,
          color: isDark ? AppTheme.backgroundColor : AppTheme.lightBackground,
        ),
      ),
    );

    return Scaffold(
      body: PremiumBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (MediaQuery.disableAnimationsOf(context))
                logo
              else
                logo
                    .animate()
                    .scale(duration: 400.ms, curve: Curves.easeOutBack)
                    .fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
