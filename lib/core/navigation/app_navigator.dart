import 'package:flutter/material.dart';
import 'package:oculve/core/widgets/app_route.dart';
import 'package:oculve/features/home/presentation/server_selection_screen.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> openServerPicker() async {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;
  await navigator.push<void>(appRoute<void>(const ServerSelectionScreen()));
}
