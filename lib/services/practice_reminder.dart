import 'package:home_widget/home_widget.dart';

/// Bridges practice data to the Android home-screen widget.
///
/// The widget turns into a reminder once 12 hours have passed since the last
/// recorded practice, and shows the lifetime total practice time. We store
/// values as strings (epoch millis / total seconds) so the native side can
/// parse them unambiguously.
class PracticeReminder {
  PracticeReminder._();

  static const String _lastKey = 'last_practice';
  static const String _totalKey = 'total_practice_seconds';
  static const String _androidProvider = 'PracticeWidgetProvider';

  /// Record that the user just started practising and refresh the widget.
  static Future<void> markPracticed() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await HomeWidget.saveWidgetData<String>(_lastKey, now.toString());
    await _update();
  }

  /// Add a finished session's duration to the lifetime total and refresh.
  static Future<void> addSession(Duration elapsed) async {
    if (elapsed.inSeconds <= 0) return;
    final prev = await HomeWidget.getWidgetData<String>(_totalKey, defaultValue: '0');
    final total = (int.tryParse(prev ?? '0') ?? 0) + elapsed.inSeconds;
    await HomeWidget.saveWidgetData<String>(_totalKey, total.toString());
    await HomeWidget.saveWidgetData<String>(
      _lastKey,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
    await _update();
  }

  /// Re-render the widget (e.g. on app launch) without changing the data.
  static Future<void> refresh() => _update();

  static Future<void> _update() async {
    try {
      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (_) {
      // No widget added yet, or platform without widget support — ignore.
    }
  }
}
