import 'package:flutter/material.dart';
import '../data/chord_library.dart';
import '../models/chord.dart';
import '../widgets/chord_diagram.dart';
import 'play_screen.dart';

/// Shows a chord's fretboard diagram in a popup (used on long-press).
void showChordDiagramPopup(BuildContext context, Chord chord) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chord.name,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                child: ChordDiagram(chord: chord, color: scheme.onSurface),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

enum SelectionMode { custom, scale, sequence }

/// One step of a custom loop: a chord and the delay (seconds) before the next.
class SeqStep {
  final String chordName;
  int delay;
  SeqStep(this.chordName, this.delay);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Every chord shown in the picker (used for the "Select all" default).
  static final List<String> _allChordNames =
      ChordLibrary.grouped.values.expand((l) => l).map((c) => c.name).toList();

  SelectionMode _mode = SelectionMode.custom;
  String _scale = ChordLibrary.scaleNames.first;
  final Set<String> _scaleDeselected = {}; // chords excluded from current scale
  final Set<String> _customSelected = {};
  final List<SeqStep> _sequence = []; // ordered loop steps (sequence mode)
  int _delay = 2;
  int _sessionMinutes = 0; // 0 = endless (practice until stopped)

  // Metronome (tempo) settings — live in the settings drawer.
  bool _tempoMode = false;
  bool _beatFlash = true; // screen flash on each beat in tempo mode
  int _bpm = 90;
  int _beatsPerBar = 4;
  int _barsPerChord = 1; // chord length in bars for Chords/Scale modes

  // The custom picker is built once and kept alive (via Offstage), so editing
  // it only rebuilds the picker itself — not this whole screen.
  late final Widget _customPicker = _CustomChordPicker(
    selection: _customSelected,
    universe: _allChordNames,
    onChanged: () => setState(() {}), // refresh the play-bar count only
  );

  @override
  void initState() {
    super.initState();
    // The merged Chords tab starts with every chord selected.
    _customSelected.addAll(_allChordNames);
  }

  /// The chords that will actually be practiced for the current mode.
  List<Chord> get _activeChords {
    switch (_mode) {
      case SelectionMode.scale:
        return ChordLibrary.chordsForScale(_scale)
            .where((c) => !_scaleDeselected.contains(c.name))
            .toList();
      case SelectionMode.custom:
        return _customSelected
            .map((n) => ChordLibrary.byName(n))
            .whereType<Chord>()
            .toList();
      case SelectionMode.sequence:
        return _sequence
            .map((s) => ChordLibrary.byName(s.chordName))
            .whereType<Chord>()
            .toList();
    }
  }

  Duration? get _sessionLimit =>
      _sessionMinutes == 0 ? null : Duration(minutes: _sessionMinutes);

  void _startPractice() {
    final chords = _activeChords;
    if (chords.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mode == SelectionMode.sequence
              ? 'Add at least 2 chords to your loop.'
              : 'Select at least 2 chords to practice.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayScreen(
          chords: chords,
          delaySeconds: _delay,
          sessionLimit: _sessionLimit,
          stepDelays: _mode == SelectionMode.sequence
              ? _sequence.map((s) => s.delay).toList()
              : null,
          tempoMode: _tempoMode,
          bpm: _bpm,
          beatsPerBar: _beatsPerBar,
          barsPerChord: _barsPerChord,
          beatFlash: _beatFlash,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _activeChords.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('LoopChords'),
        centerTitle: true,
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Settings',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _settingsDrawer(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _sectionTitle('Choose your chords'),
          const SizedBox(height: 8),
          _modeSelector(),
          const SizedBox(height: 16),
          // All bodies stay in the tree; only the active one is laid out.
          // Cached widget instances let the framework skip rebuilding them.
          Offstage(
            offstage: _mode != SelectionMode.scale,
            child: _ScalePicker(
              scale: _scale,
              deselected: _scaleDeselected,
              onScaleChanged: (s) => setState(() {
                _scale = s;
                _scaleDeselected.clear(); // new key starts fully selected
              }),
              onToggle: (name, selected) => setState(() {
                if (selected) {
                  _scaleDeselected.remove(name);
                } else {
                  _scaleDeselected.add(name);
                }
              }),
            ),
          ),
          Offstage(offstage: _mode != SelectionMode.custom, child: _customPicker),
          Offstage(
            offstage: _mode != SelectionMode.sequence,
            child: _SequenceBuilder(
              sequence: _sequence,
              tempoMode: _tempoMode,
              onChanged: () => setState(() {}),
            ),
          ),
          const SizedBox(height: 24),
          // Delay only applies to timer mode, and not to Loop (per-step there).
          if (!_tempoMode && _mode != SelectionMode.sequence) ...[
            _sectionTitle('Delay between chords'),
            const SizedBox(height: 8),
            _delaySelector(),
            const SizedBox(height: 24),
          ],
          _sectionTitle('Session length'),
          const SizedBox(height: 8),
          _sessionSelector(),
        ],
      ),
      bottomNavigationBar: _playBar(count),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      );

  Widget _modeSelector() {
    return SegmentedButton<SelectionMode>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: SelectionMode.custom, label: Text('Chords')),
        ButtonSegment(value: SelectionMode.scale, label: Text('Scale')),
        ButtonSegment(value: SelectionMode.sequence, label: Text('Loop')),
      ],
      selected: {_mode},
      onSelectionChanged: (s) => setState(() => _mode = s.first),
    );
  }

  Widget _delaySelector() {
    return Wrap(
      spacing: 10,
      children: [1, 2, 3, 4, 5].map((d) {
        return ChoiceChip(
          showCheckmark: false,
          label: Text('${d}s'),
          selected: _delay == d,
          onSelected: (_) => setState(() => _delay = d),
        );
      }).toList(),
    );
  }

  // Right-side settings drawer: metronome + tempo-only options.
  Widget _settingsDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                const Text('Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 16),
            _sectionTitle('Metronome'),
            const SizedBox(height: 8),
            _metronomeSection(),
            if (_tempoMode)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Beat flash',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                value: _beatFlash,
                onChanged: (v) => setState(() => _beatFlash = v),
              ),
            if (_tempoMode && _mode != SelectionMode.sequence) ...[
              const SizedBox(height: 20),
              _sectionTitle('Chord length'),
              const SizedBox(height: 8),
              _barsSelector(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metronomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tempo mode',
              style: TextStyle(fontWeight: FontWeight.w600)),
          value: _tempoMode,
          onChanged: (v) => setState(() => _tempoMode = v),
        ),
        if (_tempoMode) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Tempo', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$_bpm BPM',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _bpm > 40 ? () => setState(() => _bpm--) : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Slider(
                  min: 40,
                  max: 208,
                  value: _bpm.toDouble(),
                  onChanged: (v) => setState(() => _bpm = v.round()),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _bpm < 208 ? () => setState(() => _bpm++) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Beats per bar', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [2, 3, 4, 6].map((b) {
              return ChoiceChip(
                showCheckmark: false,
                label: Text('$b'),
                selected: _beatsPerBar == b,
                onSelected: (_) => setState(() => _beatsPerBar = b),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _barsSelector() {
    // Chord length in bars for the random (non-loop) modes.
    return Wrap(
      spacing: 10,
      children: [1, 2, 4].map((b) {
        return ChoiceChip(
          showCheckmark: false,
          label: Text('$b ${b == 1 ? "bar" : "bars"}'),
          selected: _barsPerChord == b,
          onSelected: (_) => setState(() => _barsPerChord = b),
        );
      }).toList(),
    );
  }

  Widget _sessionSelector() {
    // 0 = endless; other values are minutes.
    const options = {0: 'Endless', 1: '1 min', 3: '3 min', 5: '5 min', 10: '10 min'};
    return Wrap(
      spacing: 10,
      children: options.entries.map((e) {
        return ChoiceChip(
          showCheckmark: false,
          label: Text(e.value),
          selected: _sessionMinutes == e.key,
          onSelected: (_) => setState(() => _sessionMinutes = e.key),
        );
      }).toList(),
    );
  }

  Widget _playBar(int count) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: count >= 2 ? _startPractice : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          icon: const Icon(Icons.play_arrow),
          label: Text('Play  ($count chords • ${_delay}s)'),
        ),
      ),
    );
  }
}

/// Scale picker: a key dropdown plus selectable chips for that scale's chords,
/// so individual chords can be deselected before practising.
class _ScalePicker extends StatelessWidget {
  final String scale;
  final Set<String> deselected;
  final ValueChanged<String> onScaleChanged;
  final void Function(String name, bool selected) onToggle;

  const _ScalePicker({
    required this.scale,
    required this.deselected,
    required this.onScaleChanged,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final chords = ChordLibrary.chordsForScale(scale);
    final selectedCount = chords.where((c) => !deselected.contains(c.name)).length;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: scale,
              decoration: const InputDecoration(
                labelText: 'Key / Scale',
                border: OutlineInputBorder(),
              ),
              items: ChordLibrary.scaleNames
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => onScaleChanged(v ?? scale),
            ),
            const SizedBox(height: 12),
            Text('$selectedCount of ${chords.length} selected',
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chords.map((c) {
                return GestureDetector(
                  onLongPress: () => showChordDiagramPopup(context, c),
                  child: FilterChip(
                    showCheckmark: false,
                    label: Text(c.name),
                    selected: !deselected.contains(c.name),
                    onSelected: (v) => onToggle(c.name, v),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom chord picker. Owns its own rebuilds so toggling a chip does not
/// rebuild the whole home screen. Mutates the shared [selection] set in place
/// and notifies the parent (for the play-bar count) via [onChanged].
class _CustomChordPicker extends StatefulWidget {
  final Set<String> selection;
  final List<String> universe; // every selectable chord name
  final VoidCallback onChanged;

  const _CustomChordPicker({
    required this.selection,
    required this.universe,
    required this.onChanged,
  });

  @override
  State<_CustomChordPicker> createState() => _CustomChordPickerState();
}

class _CustomChordPickerState extends State<_CustomChordPicker> {
  void _toggle(String name, bool selected) {
    setState(() {
      if (selected) {
        widget.selection.add(name);
      } else {
        widget.selection.remove(name);
      }
    });
    widget.onChanged();
  }

  void _toggleSelectAll() {
    final allSelected = widget.selection.length >= widget.universe.length;
    setState(() {
      widget.selection.clear();
      if (!allSelected) widget.selection.addAll(widget.universe);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selection.length;
    final total = widget.universe.length;
    // Tristate: all -> true, none -> false, some -> null (dash).
    final bool? allState =
        selected == 0 ? false : (selected >= total ? true : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _toggleSelectAll,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  tristate: true,
                  value: allState,
                  onChanged: (_) => _toggleSelectAll(),
                ),
                const Text('Select all',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                Text('$selected / $total',
                    style: TextStyle(color: scheme.primary)),
              ],
            ),
          ),
        ),
        const Divider(),
        ...ChordLibrary.grouped.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: entry.value.map((c) {
                    return GestureDetector(
                      onLongPress: () => showChordDiagramPopup(context, c),
                      child: FilterChip(
                        showCheckmark: false,
                        label: Text(c.name),
                        selected: widget.selection.contains(c.name),
                        onSelected: (v) => _toggle(c.name, v),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Loop builder: an ordered list of chords with an editable delay between each
/// (the last delay loops back to the first chord). Manages its own rebuilds.
class _SequenceBuilder extends StatefulWidget {
  final List<SeqStep> sequence;
  final bool tempoMode; // true → durations are bars, false → seconds
  final VoidCallback onChanged;

  const _SequenceBuilder({
    required this.sequence,
    required this.tempoMode,
    required this.onChanged,
  });

  @override
  State<_SequenceBuilder> createState() => _SequenceBuilderState();
}

class _SequenceBuilderState extends State<_SequenceBuilder> {
  static const int _minDelay = 1;
  static const int _maxDelay = 9;

  String _unitWord(int v) =>
      widget.tempoMode ? (v == 1 ? 'bar' : 'bars') : (v == 1 ? 'sec' : 'secs');

  void _changeDelay(int index, int by) {
    setState(() {
      final v = widget.sequence[index].delay + by;
      widget.sequence[index].delay = v.clamp(_minDelay, _maxDelay);
    });
    widget.onChanged();
  }

  void _remove(int index) {
    setState(() => widget.sequence.removeAt(index));
    widget.onChanged();
  }

  void _add(String name) {
    setState(() => widget.sequence.add(SeqStep(name, 2)));
    widget.onChanged();
  }

  void _openAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (_, controller) => StatefulBuilder(
            builder: (_, setSheet) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Row(
                  children: [
                    const Text('Add a chord',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${widget.sequence.length} in loop',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to add (order matters). Long-press to preview.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ...ChordLibrary.grouped.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(entry.key,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: entry.value.map((c) {
                            return GestureDetector(
                              onLongPress: () => showChordDiagramPopup(context, c),
                              child: ActionChip(
                                avatar: const Icon(Icons.add, size: 18),
                                label: Text(c.name),
                                onPressed: () {
                                  _add(c.name);
                                  setSheet(() {}); // refresh the count in the sheet
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.sequence.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Build a loop',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(
                    'Add chords in the order you want to play them, then set the '
                    'delay between each. The loop repeats until your session ends.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                children: [
                  for (int i = 0; i < widget.sequence.length; i++)
                    _stepTile(scheme, i),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _openAddSheet,
          icon: const Icon(Icons.add),
          label: const Text('Add chord'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }

  Widget _stepTile(ColorScheme scheme, int i) {
    final step = widget.sequence[i];
    final isLast = i == widget.sequence.length - 1;
    final chord = ChordLibrary.byName(step.chordName);

    return Column(
      children: [
        // Chord row.
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Text('${i + 1}',
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onLongPress: chord == null
                    ? null
                    : () => showChordDiagramPopup(context, chord),
                child: Text(step.chordName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
            ),
            IconButton(
              onPressed: () => _remove(i),
              icon: const Icon(Icons.close),
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        // Delay connector to the next chord (or back to the first if last).
        Padding(
          padding: const EdgeInsets.only(left: 14, top: 2, bottom: 6),
          child: Row(
            children: [
              Icon(isLast ? Icons.refresh : Icons.south,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              _delayStepper(scheme, i),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_unitWord(step.delay)} · ${isLast ? "loop to #1" : "to next"}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _delayStepper(ColorScheme scheme, int i) {
    final delay = widget.sequence[i].delay;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove, delay > _minDelay, () => _changeDelay(i, -1)),
          SizedBox(
            width: 28,
            child: Text('$delay',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          _stepBtn(Icons.add, delay < _maxDelay, () => _changeDelay(i, 1)),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return InkResponse(
      onTap: enabled ? onTap : null,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon,
            size: 18,
            color: enabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).disabledColor),
      ),
    );
  }
}
