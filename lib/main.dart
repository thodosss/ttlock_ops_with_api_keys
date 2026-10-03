import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'theme/ops_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: OpsColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const TtlockOpsApp());
}

class TtlockOpsApp extends StatelessWidget {
  const TtlockOpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TTLock Ops',
      debugShowCheckedModeBanner: false,
      theme: buildOpsTheme(),
      home: const HomeScreen(),
    );
  }
}
