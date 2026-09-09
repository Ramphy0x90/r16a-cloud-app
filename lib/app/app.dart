import 'package:flutter/material.dart';

import 'shell/home_shell.dart';
import 'theme/app_theme.dart';

class R16aCloudApp extends StatelessWidget {
  const R16aCloudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'R16a Cloud',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
