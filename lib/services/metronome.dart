import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// A drift-free metronome that plays an accented click on beat 1 of each bar
/// and a normal click on the other beats.
///
/// Beats are pinned to an absolute grid derived from a [Stopwatch], so they
/// never accumulate drift. [beatInBar] (1-based, 0 = idle) drives the on-screen
/// beat dot, and [onBeat] notifies listeners on every beat so the play screen
/// can advance chords on the downbeat.
class MetronomeEngine {
  final int bpm;
  final int beatsPerBar;

  MetronomeEngine({required this.bpm, required this.beatsPerBar});

  // AudioPools preload several low-latency players per sound; each start()
  // plays a fresh player from the beginning, so the click fires every beat.
  AudioPool? _tickPool;
  AudioPool? _tockPool;
  bool _loaded = false;

  final Stopwatch _watch = Stopwatch();
  Timer? _timer;
  int _beatsFired = 0; // total beats emitted since start()

  /// 1-based beat within the current bar (0 = not running).
  final ValueNotifier<int> beatInBar = ValueNotifier<int>(0);

  /// Called for every beat: (globalBeatIndex, beatInBar 1-based, isDownbeat).
  void Function(int globalIndex, int beatInBar, bool isDownbeat)? onBeat;

  double get _beatMs => 60000.0 / bpm;

  Future<void> load() async {
    try {
      _tickPool = await AudioPool.createFromAsset(
        path: 'audio/tick.wav',
        minPlayers: 2,
        maxPlayers: 4,
        playerMode: PlayerMode.lowLatency,
      );
      _tockPool = await AudioPool.createFromAsset(
        path: 'audio/tock.wav',
        minPlayers: 2,
        maxPlayers: 4,
        playerMode: PlayerMode.lowLatency,
      );
      _loaded = true;
    } catch (_) {
      // Audio unavailable (e.g. headless test) — beats still fire silently.
      _loaded = false;
    }
  }

  void start() {
    _beatsFired = 0;
    _watch
      ..reset()
      ..start();
    _timer = Timer.periodic(const Duration(milliseconds: 8), (_) => _drain());
    _drain(); // emit the first beat immediately
  }

  void pause() {
    _watch.stop();
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (_timer != null) return;
    _watch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 8), (_) => _drain());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _watch
      ..stop()
      ..reset();
    _beatsFired = 0;
    beatInBar.value = 0;
  }

  void _drain() {
    final elapsedMs = _watch.elapsedMicroseconds / 1000.0;
    // Emit any beats whose scheduled grid time has passed (catch-up safe).
    while (elapsedMs >= _beatsFired * _beatMs) {
      _emit(_beatsFired);
      _beatsFired++;
    }
  }

  void _emit(int globalIndex) {
    final inBar = (globalIndex % beatsPerBar) + 1;
    final isDown = inBar == 1;
    beatInBar.value = inBar;
    if (_loaded) _click(isDown ? _tickPool : _tockPool);
    onBeat?.call(globalIndex, inBar, isDown);
  }

  Future<void> _click(AudioPool? pool) async {
    if (pool == null) return;
    try {
      final stop = await pool.start(volume: 1.0);
      // Recycle the player shortly after the (very short) click finishes so the
      // pool never grows in low-latency mode.
      Timer(const Duration(milliseconds: 130), stop);
    } catch (_) {
      // Ignore transient playback errors.
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    beatInBar.dispose();
    _tickPool?.dispose();
    _tockPool?.dispose();
  }
}
