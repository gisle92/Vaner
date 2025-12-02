import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Notification settings (stored in Firestore, backend can later read this)
class NotificationSettingsScreen extends StatefulWidget {
  final String userId;

  const NotificationSettingsScreen({super.key, required this.userId});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loading = true;
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('settings')
          .doc('notification');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await _settingsDoc.get();
    if (snap.exists) {
      final data = snap.data()!;
      _enabled = (data['enabled'] as bool?) ?? false;
      final minuteOfDay = (data['minuteOfDay'] as int?) ?? (20 * 60);
      _time = TimeOfDay(
        hour: minuteOfDay ~/ 60,
        minute: minuteOfDay % 60,
      );
    }
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final minuteOfDay = _time.hour * 60 + _time.minute;

    final data = {
      'enabled': _enabled,
      'minuteOfDay': minuteOfDay,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Keep existing subcollection doc
    await _settingsDoc.set(
      data,
      SetOptions(merge: true),
    );

    // Mirror settings on the user root doc for easier backend queries
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .set(
      {
        'notification': data,
      },
      SetOptions(merge: true),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varslingsinnstillinger lagret')),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) {
      setState(() {
        _time = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Varsler'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Daglig påminnelse'),
                    subtitle: const Text(
                        'Lagre når du vil få påminnelse om dagens vaner.'),
                    value: _enabled,
                    onChanged: (val) {
                      setState(() {
                        _enabled = val;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    enabled: _enabled,
                    onTap: _enabled ? _pickTime : null,
                    leading: const Icon(Icons.schedule),
                    title: const Text('Tidspunkt'),
                    subtitle: Text(_time.format(context)),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Lagre'),
                  ),
                ],
              ),
            ),
    );
  }
}
