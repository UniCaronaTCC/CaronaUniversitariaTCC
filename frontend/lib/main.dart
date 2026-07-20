import 'package:flutter/material.dart';

import 'auth/login.dart';
import 'config/app_theme.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginTela(),
    ),
  );
}
