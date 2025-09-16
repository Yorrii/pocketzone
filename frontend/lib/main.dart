import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/record_screen.dart';
import 'screens/list_screen.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const RecordScreen()),
      GoRoute(path: '/list', builder: (_, __) => const ListScreen()),
    ]);

    return MaterialApp.router(
      title: 'Pocket Zone',
      theme: ThemeData.light(useMaterial3: true),
      routerConfig: router,
    );
  }
}
