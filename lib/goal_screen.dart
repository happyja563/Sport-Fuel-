import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gemini_ai.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  // Results
  String _plan = '';
  String _advice = '';
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // Inputs
  final TextEditingController _goalNotesCtrl = TextEditingController();

  // Streaks (simple)
  int _streakCount = 0;
  DateTime? _lastCompletedDate;

  // Loading flags
  bool _busyPlan = false;
  bool _busyAdvice = false;

  @override
  void initState() {
    super.initState();
    _initData(); // async init for persisted texts
    _loadStreakAndNormalize();
  }

  @override
  void dispose() {
    _goalNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('streak_count', _streakCount);
    await prefs.setString(
      'streak_last',
      _lastCompletedDate?.toIso8601String() ?? '',
    );
  }

  Future<void> _loadStreakAndNormalize() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('streak_count') ?? 0;
    final lastStr = prefs.getString('streak_last');

    DateTime? last = (lastStr == null || lastStr.isEmpty)
        ? null
        : DateTime.tryParse(lastStr);
    final today = _dateOnly(DateTime.now());
    if (last != null) last = _dateOnly(last);

    int normalized = count;
    if (last == null) {
      normalized = 0; // no history
    } else {
      final yesterday = today.subtract(const Duration(days: 1));
      if (last == today) {
        // already counted today -> keep as-is
      } else if (last == yesterday) {
        // not counted yet today but still a valid streak -> keep as-is
      } else {
        // missed ≥ 1 day -> reset
        normalized = 0;
      }
    }

    if (!mounted) return;
    setState(() {
      _streakCount = normalized;
      _lastCompletedDate = last;
    });
  }

  // -------------------- Data Init --------------------

  Future<void> _initData() async {
    final macros = await GeminiService.instance.getSavedMacroRecsText();
    final advice = await GeminiService.instance.getSavedAdviceToday();

    if (!mounted) return;
    setState(() {
      _plan = macros ?? '';
      _advice = advice ?? '';
    });
  }

  // -------------------- Actions --------------------

  Future<void> _buildPlan() async {
    setState(() => _busyPlan = true);
    try {
      final text = await GeminiService.instance.recommendMacrosFromDB();
      if (!mounted) return;
      setState(() => _plan = text ?? '');
    } finally {
      if (mounted) setState(() => _busyPlan = false);
    }
  }

  Future<void> _getAdvice() async {
    setState(() => _busyAdvice = true);
    try {
      final notes = _goalNotesCtrl.text;
      final text = await GeminiService.instance.getAdvice(notes);
      if (!mounted) return;
      setState(() => _advice = text ?? '');
    } finally {
      if (mounted) setState(() => _busyAdvice = false);
    }
  }

  Future<void> _markTodayDone() async {
    final today = _dateOnly(DateTime.now());

    if (_lastCompletedDate == today) {
      // already counted today; do nothing
    } else if (_lastCompletedDate == today.subtract(const Duration(days: 1))) {
      _streakCount += 1;
      _lastCompletedDate = today;
    } else {
      // null or gap >= 1 day -> start/restart streak
      _streakCount = 1;
      _lastCompletedDate = today;
    }

    if (mounted) setState(() {});
    await _saveStreak();
  }

  Future<void> _resetStreak() async {
    setState(() {
      _streakCount = 0;
      _lastCompletedDate = null;
    });
    await _saveStreak();
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Goals')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Build Plan (macro recs)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Build Plan',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busyPlan ? null : _buildPlan,
                      child: _busyPlan
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Build Plan'),
                    ),
                  ),
                  if (_plan.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SelectableText(_plan),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // AI Coach (advice)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Coach',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _goalNotesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Additional information',
                      hintText: 'Notes, why it matters, milestones...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busyAdvice ? null : _getAdvice,
                      child: _busyAdvice
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Get Advice'),
                    ),
                  ),
                  if (_advice.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SelectableText(_advice),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Streaks
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Streaks',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        child: Text(
                          '$_streakCount',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _streakCount == 0
                              ? 'No streak yet. Mark today done to start!'
                              : "You're on a $_streakCount-day streak. Keep it going!",
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _markTodayDone,
                        child: const Text('Mark Today Done'),
                      ),
                    ],
                  ),
                  if (_lastCompletedDate != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Last completed: '
                          '${_lastCompletedDate!.year}-${_lastCompletedDate!.month.toString().padLeft(2, '0')}-${_lastCompletedDate!.day.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}