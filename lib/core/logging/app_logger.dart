class AppLogger {
  const AppLogger();

  void info(String message) {
    assert(() {
      // ignore: avoid_print
      print('[MediPulse] $message');
      return true;
    }());
  }

  void error(String message, [Object? error]) {
    assert(() {
      // ignore: avoid_print
      print('[MediPulse][error] $message');
      return true;
    }());
  }
}
