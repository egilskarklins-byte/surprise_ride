import 'package:flutter/material.dart';

import '../../services/app_language_service.dart';
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
          title: Text(
            AppLanguageService.tr(
              lv: 'Notīrīt vēsturi?',
              en: 'Clear history?',
            ),
          ),
          content: Text(
            AppLanguageService.tr(
              lv: 'Tiks dzēsta visa POI vēsture un apmeklējumu dati.',
              en: 'All POI history and visited data will be deleted.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: Text(
                AppLanguageService.tr(
                  lv: 'Atcelt',
                  en: 'Cancel',
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: Text(
                AppLanguageService.tr(
                  lv: 'Dzēst',
                  en: 'Delete',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _historyService.clearHistory();

    if (!mounted) return;

    await _loadStats();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLanguageService.tr(
            lv: 'Vēsture notīrīta',
            en: 'History cleared',
          ),
        ),
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
        title: Text(
          AppLanguageService.tr(
            lv: 'Mana vēsture',
            en: 'My History',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: AppLanguageService.tr(
              lv: 'Notīrīt vēsturi',
              en: 'Clear history',
            ),
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
            title: AppLanguageService.tr(
              lv: 'Apmeklētie POI',
              en: 'Visited POIs',
            ),
            value: _visitedCount.toString(),
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 12),
          _statCard(
            title: AppLanguageService.tr(
              lv: 'Izvēlētie POI kopā',
              en: 'Selected POIs total',
            ),
            value: _selectedCount.toString(),
            icon: Icons.touch_app_outlined,
          ),
          const SizedBox(height: 12),
          _statCard(
            title: AppLanguageService.tr(
              lv: 'Ģenerētie POI kopā',
              en: 'Generated POIs total',
            ),
            value: _generatedCount.toString(),
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: 24),
          Text(
            AppLanguageService.tr(
              lv: 'POI vēsture',
              en: 'POI History',
            ),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(
                  AppLanguageService.tr(
                    lv: 'Vēsture vēl ir tukša',
                    en: 'History is still empty',
                  ),
                ),
                subtitle: Text(
                  AppLanguageService.tr(
                    lv: 'Izvēlies vai apmeklē POI, un tie parādīsies šeit.',
                    en: 'Select or visit POIs, and they will appear here.',
                  ),
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
      AppLanguageService.tr(
        lv: 'Izvēlēts: ${entry.selectedCount}',
        en: 'Selected: ${entry.selectedCount}',
      ),
      AppLanguageService.tr(
        lv: 'Ģenerēts: ${entry.generatedCount}',
        en: 'Generated: ${entry.generatedCount}',
      ),
    ];

    if (entry.visited) {
      subtitleParts.insert(
        0,
        AppLanguageService.tr(
          lv: '✓ Apmeklēts',
          en: '✓ Visited',
        ),
      );
    }

    return Card(
      color: entry.visited ? Colors.green.withValues(alpha: 0.04) : null,
      child: ListTile(
        leading: Icon(
          entry.visited ? Icons.check_circle_outline : Icons.place_outlined,
        ),
        title: Text(
          entry.name.isEmpty
              ? AppLanguageService.tr(
            lv: 'Bez nosaukuma',
            en: 'Unnamed',
          )
              : entry.name,
        ),
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