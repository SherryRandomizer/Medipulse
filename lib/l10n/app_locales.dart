import 'package:flutter/material.dart';

class AppLocales {
  static const codes = ['en', 'es', 'ur', 'ar'];

  static const labels = {
    'en': 'English',
    'es': 'Español',
    'ur': 'اردو',
    'ar': 'العربية',
  };

  static Locale resolve(String? code) {
    final normalized = (code ?? 'en').split('_').first.split('-').first;
    if (codes.contains(normalized)) return Locale(normalized);
    return const Locale('en');
  }
}
