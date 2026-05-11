import 'package:flutter/material.dart';

import '../../services/poi_history_service.dart';

class HistoryStatsScreen extends StatefulWidget {
  const HistoryStatsScreen({super.key});

  @override
  State<HistoryStatsScreen> createState() => _HistoryStatsScreenState();
}

class _HistoryStatsScreenState extends State<HistoryStatsScreen> {
  final PoiHistoryService _historyService = PoiHistoryService();

  bool _isLoading = true;
  int _visitedCount = 0;
  int _selectedCount = 0;
  int _generatedCount = 0;

  List<PoiHistoryEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }
  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Notīrīt vēsturi?'),
          content: const Text(
            'Tiks dzēsta visa POI vēsture un apmeklējumu dati.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Atcelt'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Dzēst'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _historyService.clearHistory();

    if (!mounted) return;

    await _loadStats();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vēsture notīrīta'),
      ),
    );
  }
  Future<void> _loadStats() async {
    final history = await _historyService.loadHistory();

    final entries = history.values.where((entry) {
      return entry.selectedCount > 0 || entry.visited;
    }).toList();

    entries.sort((a, b) {
      if (a.visited != b.visited) {
        return b.visited ? 1 : -1;
      }

      final activityA = a.selectedCount + a.generatedCount;
      final activityB = b.selectedCount + b.generatedCount;

      return activityB.compareTo(activityA);
    });

    if (!mounted) return;

    setState(() {
      _entries = entries;
      _visitedCount = entries.where((entry) => entry.visited).length;
      _selectedCount = entries.fold<int>(
        0,
            (sum, entry) => sum + entry.selectedCount,
      );
      _generatedCount = entries.fold<int>(
        0,
            (sum, entry) => sum + entry.generatedCount,
      );
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mana vēsture'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Notīrīt vēsturi',
            onPressed: _confirmClearHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statCard(
            title: 'Apmeklētie POI',
            value: _visitedCount.toString(),
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 12),
          _statCard(
            title: 'Izvēlētie POI kopā',
            value: _selectedCount.toString(),
            icon: Icons.touch_app_outlined,
          ),
          const SizedBox(height: 12),
          _statCard(
            title: 'Ģenerētie POI kopā',
            value: _generatedCount.toString(),
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: 24),
          const Text(
            'POI vēsture',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Vēsture vēl ir tukša'),
                subtitle: Text(
                  'Izvēlies vai apmeklē POI, un tie parādīsies šeit.',
                ),
              ),
            )
          else
            ..._entries.map(_historyTile),
        ],
      ),
    );
  }

  Widget _historyTile(PoiHistoryEntry entry) {
    final subtitleParts = <String>[
      'Izvēlēts: ${entry.selectedCount}',
      'Ģenerēts: ${entry.generatedCount}',
    ];

    if (entry.visited) {
      subtitleParts.insert(0, '✓ Apmeklēts');
    }

    return Card(
      color: entry.visited ? Colors.green.withValues(alpha: 0.04) : null,
      child: ListTile(
        leading: Icon(
          entry.visited ? Icons.check_circle_outline : Icons.place_outlined,
        ),
        title: Text(entry.name.isEmpty ? 'Bez nosaukuma' : entry.name),
        subtitle: Text(subtitleParts.join(' • ')),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}