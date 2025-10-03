import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gemini_ai.dart';
import 'plan_db.dart';

class DashBoard extends StatefulWidget {
  const DashBoard({super.key});

  @override
  State<DashBoard> createState() => _DashBoardState();
}

class _DashBoardState extends State<DashBoard> {
  String _quote = "";
  MacroGoals? _goals;
  MacroTotals? _totals; // today's totals
  final TextEditingController _newGoalCtrl = TextEditingController();
  List<_DailyGoal> _dailyGoals = [];

  @override
  void initState() {
    super.initState();
    _refreshMacroData();
    _loadMacroGoals();
    _loadDailyGoals(); // <- load checklist
    _loadQuote();
  }

  @override
  void dispose() {
    _newGoalCtrl.dispose();
    super.dispose();
  }

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _loadQuote() async {
    final saved = await PlanDb.instance.getDailyQuote(_todayKey());
    if (saved != null && (saved['quote'] ?? '').isNotEmpty) {
      setState(
            () => _quote = saved['author']!.isEmpty
            ? saved['quote']!
            : '${saved['quote']} — ${saved['author']}',
      );
      return;
    }
    // Not saved yet today: generate and save
    final txt = await GeminiService.instance.generateDailyQuote();
    if (!mounted) return;
    setState(() => _quote = txt);
  }

  Future<void> _refreshMacroData() async {
    final g = await PlanDb.instance.getGoals();
    final t = await PlanDb.instance.getDailyTotals(_todayKey());
    if (!mounted) return;
    setState(() {
      _goals = g;
      _totals = t;
    });
  }

  // Load/save goals (simple and local) — shared_prefs is fine here
  Future<void> _loadDailyGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('daily_goals_${_todayKey()}');
    if (raw == null || raw.isEmpty) {
      setState(() => _dailyGoals = []);
      return;
    }
    final list = (jsonDecode(raw) as List)
        .map((e) => _DailyGoal.fromJson(e as Map<String, dynamic>))
        .toList();
    setState(() => _dailyGoals = list);
  }

  Future<void> _saveDailyGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_dailyGoals.map((e) => e.toJson()).toList());
    await prefs.setString('daily_goals_${_todayKey()}', raw);
  }

  Future<void> _addDailyGoal() async {
    final title = _newGoalCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _dailyGoals.add(_DailyGoal(title: title, done: false));
      _newGoalCtrl.clear();
    });
    await _saveDailyGoals();
  }

  Future<void> _toggleDailyGoal(int index, bool? value) async {
    setState(
          () => _dailyGoals[index] = _dailyGoals[index].copyWith(
        done: value ?? false,
      ),
    );
    await _saveDailyGoals();
  }

  Future<void> _deleteDailyGoal(int index) async {
    setState(() => _dailyGoals.removeAt(index));
    await _saveDailyGoals();
  }

  Widget _macroRowProgress(String label, int consumed, int? goal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        Text(
          goal == null || goal == 0 ? '$consumed / --' : '$consumed / $goal',
          style: const TextStyle(
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Future<void> _loadMacroGoals() async {
    final g = await PlanDb.instance.getGoals();
    if (!mounted) return;
    setState(() => _goals = g);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // ── Top row: Quote (left) + Macros (right)
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  // Quote
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: Text(
                            _quote.isEmpty
                                ? "…" // brief placeholder while loading
                                : _quote,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Macros
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Macro Goals",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _macroRowProgress(
                            "Calories",
                            _totals?.calories ?? 0,
                            _goals?.calories,
                          ),
                          const SizedBox(height: 8),
                          _macroRowProgress(
                            "Protein (g)",
                            _totals?.protein ?? 0,
                            _goals?.protein,
                          ),
                          const SizedBox(height: 8),
                          _macroRowProgress(
                            "Carbs (g)",
                            _totals?.carbs ?? 0,
                            _goals?.carbs,
                          ),
                          const SizedBox(height: 8),
                          _macroRowProgress(
                            "Fat (g)",
                            _totals?.fat ?? 0,
                            _goals?.fat,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Bottom: Today's Goals (fills remaining space)
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[300],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Today's Goals",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Optional: clear all completed checkmarks quickly
                        IconButton(
                          tooltip: 'Clear completed',
                          icon: const Icon(
                            Icons.checklist_rtl,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            setState(() {
                              _dailyGoals = _dailyGoals
                                  .map((g) => g.copyWith(done: false))
                                  .toList();
                            });
                            await _saveDailyGoals();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Add new goal row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newGoalCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText:
                              'Add a goal (e.g., Workout, Drink 3L water)',
                              hintStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addDailyGoal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red[400],
                          ),
                          child: const Text('Add'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Goals list
                    Expanded(
                      child: _dailyGoals.isEmpty
                          ? const Center(
                        child: Text(
                          "No goals yet. Add one above!",
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                          : ListView.builder(
                        itemCount: _dailyGoals.length,
                        itemBuilder: (context, i) {
                          final g = _dailyGoals[i];
                          return Dismissible(
                            key: ValueKey('${g.title}-$i'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              color: Colors.red[600],
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (_) async => true,
                            onDismissed: (_) => _deleteDailyGoal(i),
                            child: CheckboxListTile(
                              title: Text(
                                g.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                              value: g.done,
                              onChanged: (v) => _toggleDailyGoal(i, v),
                              controlAffinity:
                              ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              checkboxShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              activeColor: Colors.white,
                              checkColor: Colors.red[400],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Small model for daily checklist
class _DailyGoal {
  final String title;
  final bool done;
  const _DailyGoal({required this.title, required this.done});

  _DailyGoal copyWith({String? title, bool? done}) =>
      _DailyGoal(title: title ?? this.title, done: done ?? this.done);

  Map<String, dynamic> toJson() => {'title': title, 'done': done};
  factory _DailyGoal.fromJson(Map<String, dynamic> j) => _DailyGoal(
    title: j['title'] as String,
    done: j['done'] as bool? ?? false,
  );
}
