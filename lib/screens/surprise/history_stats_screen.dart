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

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final history = await _historyService.loadHistory();

    final entries = history.values.toList();

    if (!mounted) return;

    setState(() {
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
        ],
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