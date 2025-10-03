import 'package:flutter/material.dart';
import 'database.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _State();
}

class _State extends State<ProfileScreen> {
  String Name = "Haowen";
  String Age = "20";
  String Gender = "Male";
  String SportType = "fencing";
  String Weight = "60"; // store just the number; we'll show units in UI
  String Height = "172"; // same here

  bool _loading = true;
  final DBHelper _db = DBHelper();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await _db.getProfile();
    setState(() {
      Name = (p?['name'] ?? Name).toString();
      Age = (p?['age'] ?? '').toString();
      Gender = (p?['gender'] ?? '').toString();
      SportType = (p?['sportsType'] ?? '').toString();
      Weight = (p?['weight'] ?? '').toString();
      Height = (p?['height'] ?? '').toString();
      _loading = false;
    });
  }

  String _show(String s) => (s.isEmpty) ? '—' : s;

  Future<void> _openEditSheet() async {
    final nameC = TextEditingController(text: Name);
    final ageC = TextEditingController(text: Age);
    final heightC = TextEditingController(text: Height);
    final genderC = TextEditingController(text: Gender);
    final weightC = TextEditingController(text: Weight);
    final sportypeC = TextEditingController(text: SportType);
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                  textInputAction: TextInputAction.next,
                ),
                TextFormField(
                  controller: ageC,
                  decoration: const InputDecoration(labelText: 'Age'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null; // optional
                    final n = int.tryParse(v);
                    if (n == null || n < 0) return 'Enter a valid age';
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                TextFormField(
                  controller: genderC,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  textInputAction: TextInputAction.next,
                ),
                TextFormField(
                  controller: sportypeC,
                  decoration: const InputDecoration(labelText: 'Sports Type'),
                  textInputAction: TextInputAction.next,
                ),
                TextFormField(
                  controller: weightC,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null; // optional
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Enter a valid weight';
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                TextFormField(
                  controller: heightC,
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null; // optional
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Enter a valid height';
                    return null;
                  },
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;

                          await _db.saveProfile({
                            'name': nameC.text.trim(),
                            'age': int.tryParse(ageC.text.trim()),
                            'gender': genderC.text.trim(),
                            'sportsType': sportypeC.text.trim(),
                            'weight': double.tryParse(weightC.text.trim()),
                            'height': double.tryParse(heightC.text.trim()),
                          });

                          if (!mounted) return;
                          Navigator.pop(ctx);
                          await _loadProfile();
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            onPressed: _openEditSheet,
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card with avatar + name + quick tags
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    child: Text(
                      (Name.isNotEmpty ? Name[0] : '?').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Name.isEmpty ? '—' : Name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _chip('Gender', _show(Gender)),
                            _chip('Sport', _show(SportType)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Stats row (Weight / Height / Age)
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Weight',
                  _show(Weight).isEmpty ? '—' : '${_show(Weight)} kg',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Height',
                  _show(Height).isEmpty ? '—' : '${_show(Height)} cm',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Age', _show(Age))),
            ],
          ),

          const SizedBox(height: 12),

          // Details list (simple ListTiles)
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Name'),
                  subtitle: Text(_show(Name)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.male),
                  title: const Text('Gender'),
                  subtitle: Text(_show(Gender)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sports_martial_arts),
                  title: const Text('Sport Type'),
                  subtitle: Text(_show(SportType)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.monitor_weight_outlined),
                  title: const Text('Weight'),
                  subtitle: Text(Weight.isEmpty ? '—' : '$Weight kg'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.height),
                  title: const Text('Height'),
                  subtitle: Text(Height.isEmpty ? '—' : '$Height cm'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.event),
                  title: const Text('Age'),
                  subtitle: Text(_show(Age)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Edit button at bottom too (nice for thumb reach)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openEditSheet,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
            ),
          ),
        ],
      ),
    );
  }

  // Small helpers to keep UI simple
  Widget _statCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
