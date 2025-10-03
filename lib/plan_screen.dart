import 'package:flutter/material.dart';
import 'plan_db.dart';

/// Plan screen (food tracker) backed by SQLite via plan_db.dart
/// - Browse any week (Mon–Sun) with arrows or jump via calendar.
/// - Tap a day chip to view that day's meals.
/// - Add meals with a simple bottom sheet form (name + calories/macros).
/// - Swipe left on a meal to delete.
class FoodTrackerScreen extends StatefulWidget {
  const FoodTrackerScreen({super.key});

  @override
  State<FoodTrackerScreen> createState() => _FoodTrackerScreenState();
}

class _FoodTrackerScreenState extends State<FoodTrackerScreen> {
  // Current visible week start (Monday) and selected date.
  late DateTime _weekStart;
  late DateTime _selectedDate;

  // Meals for the currently selected date.
  List<Meal> _meals = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = _mondayOfWeek(now);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadMealsFor(_selectedDate);
  }

  // -------------------------- Helpers (inside class) --------------------------

  DateTime _mondayOfWeek(DateTime d) {
    // In Dart, Monday = 1 ... Sunday = 7
    final base = DateTime(d.year, d.month, d.day);
    return base.subtract(Duration(days: base.weekday - 1));
  }

  DateTime _sundayOfWeek(DateTime d) {
    final mon = _mondayOfWeek(d);
    return mon.add(const Duration(days: 6));
  }

  /// yyyy-MM-dd
  String _keyForDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _monthShort(int m) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[m];
  }

  String _weekdayShort(int weekday) {
    const w = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return w[weekday];
  }

  /// e.g., "Sep 15–21, 2025"
  String _weekRangeLabel(DateTime weekStart) {
    final start = weekStart;
    final end = _sundayOfWeek(weekStart);
    final sameMonth = start.month == end.month;
    final sameYear = start.year == end.year;
    final startPart = '${_monthShort(start.month)} ${start.day}';
    final endPart = sameMonth
        ? '${end.day}'
        : '${_monthShort(end.month)} ${end.day}';
    final yearPart = sameYear ? '${start.year}' : '${start.year}–${end.year}';
    return '$startPart–$endPart, $yearPart';
  }

  /// Approximate week number for display.
  int _weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final difference = date.difference(firstDayOfYear);
    return (difference.inDays / 7).floor() + 1;
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // -------------------------- DB Loads --------------------------

  Future<void> _loadMealsFor(DateTime date) async {
    final items = await PlanDb.instance.getMealsByDate(_keyForDate(date));
    if (!mounted) return;
    setState(() => _meals = items);
  }

  // -------------------------- UI Actions --------------------------

  void _goPrevWeek() async {
    final newStart = _weekStart.subtract(const Duration(days: 7));
    final newSelected = newStart; // default to Monday of the new week
    setState(() {
      _weekStart = newStart;
      _selectedDate = newSelected;
    });
    await _loadMealsFor(_selectedDate);
  }

  void _goNextWeek() async {
    final newStart = _weekStart.add(const Duration(days: 7));
    final newSelected = newStart;
    setState(() {
      _weekStart = newStart;
      _selectedDate = newSelected;
    });
    await _loadMealsFor(_selectedDate);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _weekStart = _mondayOfWeek(_selectedDate);
      });
      await _loadMealsFor(_selectedDate);
    }
  }

  // -------------------------- Add Food Form --------------------------

  void _showAddFoodForm() {
    final nameController = TextEditingController();
    final calController = TextEditingController();
    final proteinController = TextEditingController();
    final carbController = TextEditingController();
    final fatController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Add Food", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: "Food Name"),
              ),
              TextField(
                controller: calController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: "Calories"),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proteinController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: "Protein (g)",
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: carbController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: "Carbs (g)"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: fatController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: "Fat (g)"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a food name')),
                    );
                    return;
                  }
                  final meal = Meal(
                    dateKey: _keyForDate(_selectedDate),
                    name: name,
                    time: TimeOfDay.now().format(context),
                    calories: int.tryParse(calController.text) ?? 0,
                    protein: int.tryParse(proteinController.text) ?? 0,
                    carbs: int.tryParse(carbController.text) ?? 0,
                    fat: int.tryParse(fatController.text) ?? 0,
                  );
                  await PlanDb.instance.addMeal(meal);
                  await _loadMealsFor(_selectedDate);
                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------- Build --------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekLabel = _weekRangeLabel(_weekStart);
    final weekNum = _weekNumber(_weekStart);

    return Scaffold(
      appBar: AppBar(title: const Text('Plan'), centerTitle: true),
      body: Column(
        children: [
          // Week header with arrows and calendar button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: _goPrevWeek,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous week',
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        weekLabel,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text('Week $weekNum', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _goNextWeek,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next week',
                ),
                IconButton(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  tooltip: 'Jump to date',
                ),
              ],
            ),
          ),

          // Day chips row (Mon..Sun with date numbers)
          SizedBox(
            height: 64,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, i) {
                final dayDate = _weekStart.add(Duration(days: i));
                final isSelected = _isSameDate(dayDate, _selectedDate);
                final label = _weekdayShort(dayDate.weekday);
                final dayNum = dayDate.day;
                return ChoiceChip(
                  selected: isSelected,
                  showCheckmark: false,
                  onSelected: (_) async {
                    setState(() => _selectedDate = dayDate);
                    await _loadMealsFor(_selectedDate);
                  },
                  label: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label),
                      const SizedBox(height: 2),
                      Text(
                        dayNum.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: 7,
            ),
          ),

          const Divider(height: 24),

          // Entries list for selected date
          Expanded(child: _buildMealsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFoodForm,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget _buildMealsList() {
    if (_meals.isEmpty) {
      return _EmptyState(date: _selectedDate);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _meals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final m = _meals[index];
        return Dismissible(
          key: ValueKey(m.id ?? '${m.name}-$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async => true,
          onDismissed: (_) async {
            if (m.id != null) {
              await PlanDb.instance.deleteMeal(m.id!);
            }
            await _loadMealsFor(_selectedDate);
          },
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(.4),
            leading: const Icon(Icons.restaurant_menu),
            title: Text(m.name),
            subtitle: Text(
              '${m.calories} kcal  •  P ${m.protein}g  C ${m.carbs}g  F ${m.fat}g',
            ),
            trailing: Text(
              m.time,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.date});
  final DateTime date;

  String _monthShort(int m) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m];

  @override
  Widget build(BuildContext context) {
    final label = '${_monthShort(date.month)} ${date.day}, ${date.year}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'No items added for $label yet.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
