import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Pops the current route, or closes the app when there is nothing below it.
void goBackOrExit(BuildContext context) {
  goBackOrExitRouter(GoRouter.of(context));
}

void goBackOrExitRouter(GoRouter router) {
  if (router.canPop()) {
    router.pop();
    return;
  }
  SystemNavigator.pop();
}
