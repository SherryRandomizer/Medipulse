import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medipulse/app.dart';
import 'package:medipulse/bootstrap.dart';
import 'package:medipulse/core/logging/app_logger.dart';

Future<void> main() async {
  try {
    final container = await bootstrap();
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const MediPulseApp(),
      ),
    );
  } catch (error) {
    const AppLogger().error('Startup failed');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'MediPulse could not start. Please reopen the app. Your reminders are stored on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
