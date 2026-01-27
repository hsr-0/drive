import 'dart:async';

class MyDebouncer {
  final Duration delay;
  Timer? _timer;

  MyDebouncer({required this.delay});

  void run(void Function() action) {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }
    _timer = Timer(delay, action);
  }
}
