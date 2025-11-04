import 'package:flutter/material.dart';

extension ContextExtension on BuildContext{
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}