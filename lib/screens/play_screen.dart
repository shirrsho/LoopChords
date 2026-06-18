import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/chord.dart';
import '../services/practice_reminder.dart';
import '../widgets/chord_diagram.dart';

class PlayScreen extends StatefulWidget {
  final List<Chord> chords;
  final int delaySeconds;

  const PlayScreen({
    super.key,
    required this.chords,
    required this.delaySeconds,
  });

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin {
  final Random _rng = Random();
  late Chord _current;
  late Chord _next;
  late AnimationController _progress;
  bool _paused = false;

  // 3..2..1 countdown shown before practice starts (0 = practising).
  int _countdown = 3;
  Timer? _countdownTimer;

  // Total elapsed practice time (pauses while practice is paused).
  final Stopwatch _watch = Stopwatch();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Keep the screen on for the whole session, and hide system UI so the big
    // chord is the only thing on screen.
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _current = _randomChord(exclude: null);
    _next = _randomChord(exclude: _current);

    _progress = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.delaySeconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_paused) {
          _advance();
        }
      });

    // Run the countdown first; practice (timers + clock) begins after it.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _beginPractice();
      }
    });
  }

  void _beginPractice() {
    _watch.start();
    _progress.forward();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {}); // refresh the elapsed-time display
    });
    // Starting a session clears the widget reminder.
    PracticeReminder.markPracticed();
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Chord _randomChord({Chord? exclude}) {
    if (widget.chords.length == 1) return widget.chords.first;
    Chord c;
    do {
      c = widget.chords[_rng.nextInt(widget.chords.length)];
    } while (exclude != null && c.name == exclude.name);
    return c;
  }

  void _advance() {
    setState(() {
      _current = _next;
      _next = _randomChord(exclude: _current);
    });
    _progress
      ..reset()
      ..forward();
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _progress.stop();
        _watch.stop();
      } else {
        _progress.forward();
        _watch.start();
      }
    });
  }

  void _skip() => _advance();

  @override
  void dispose() {
    // Record this session's length toward the lifetime total.
    PracticeReminder.addSession(_watch.elapsed);
    _countdownTimer?.cancel();
    _ticker?.cancel();
    _progress.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1116),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
            // Timer progress bar across the top.
            AnimatedBuilder(
              animation: _progress,
              builder: (_, _) => LinearProgressIndicator(
                value: _progress.value,
                minHeight: 5,
                backgroundColor: Colors.white10,
                color: scheme.primary,
              ),
            ),

            // Top bar: playback controls.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  _controls(),
                  const Spacer(),
                  Text(
                    '${widget.chords.length} chords',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Current chord — name + big fretboard, fills the free space.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
                child: Column(
                  children: [
                    // Name sits centered between the top and the diagram.
                    const Spacer(flex: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _current.name,
                        style: const TextStyle(
                          fontSize: 88,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: ChordDiagram(chord: _current),
                    ),
                    const Spacer(flex: 3),
                  ],
                ),
              ),
            ),

            // Bottom bar: elapsed time on the left, next-chord preview on the right.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _elapsedTime(scheme),
                  const Spacer(),
                  _nextPreview(scheme),
                ],
              ),
            ),
          ],
            ),
          ),
          if (_countdown > 0) _countdownOverlay(scheme),
        ],
      ),
    );
  }

  // Full-screen 3..2..1 countdown shown before the first chord.
  Widget _countdownOverlay(ColorScheme scheme) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0E1116),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Get ready',
              style: TextStyle(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              '$_countdown',
              style: TextStyle(
                color: scheme.primary,
                fontSize: 140,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Elapsed practice time (pauses with the session).
  Widget _elapsedTime(ColorScheme scheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 20, color: scheme.primary),
        const SizedBox(width: 6),
        Text(
          _formatElapsed(_watch.elapsed),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        if (_paused) ...[
          const SizedBox(width: 8),
          Text('paused', style: TextStyle(color: scheme.primary, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _controls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: 'Stop',
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: _togglePause,
          icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
          tooltip: _paused ? 'Resume' : 'Pause',
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: _skip,
          icon: const Icon(Icons.skip_next),
          tooltip: 'Skip',
        ),
      ],
    );
  }

  Widget _nextPreview(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEXT',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _next.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 58,
            child: ChordDiagram(chord: _next, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
