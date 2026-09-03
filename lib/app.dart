import 'package:flutter/material.dart';

import 'repositories/repository_factory.dart';
import 'screens/app_shell.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class ConvieneApp extends StatefulWidget {
  const ConvieneApp({super.key});

  @override
  State<ConvieneApp> createState() => _ConvieneAppState();
}

class _ConvieneAppState extends State<ConvieneApp> {
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = AppState(repository: createRepository());
    _state.initialize();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: _state,
      child: MaterialApp(
        title: 'Conviene',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const AppShell(),
      ),
    );
  }
}
