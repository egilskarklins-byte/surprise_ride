import 'package:flutter/material.dart';

import '../../services/route_history_service.dart';
import 'surprise_route_screen.dart';

class SavedRoutesScreen extends StatefulWidget {
  const SavedRoutesScreen({super.key});

  @override
  State<SavedRoutesScreen> createState() => _SavedRoutesScreenState();
}

class _SavedRoutesScreenState extends State<SavedRoutesScreen> {
  final RouteHistoryService _service = RouteHistoryService();

  bool _isLoading = true;
  List<SavedRoute> _routes = [];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final routes = await _service.loadRoutes();

    if (!mounted) return;

    setState(() {
      _routes = routes;
      _isLoading = false;
    });
  }

  Future<void> _clearRoutes() async {
    await _service.clearRoutes();
    await _loadRoutes();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FB),
      appBar: AppBar(
        title: const Text('Mani maršruti'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _routes.isEmpty ? null : _clearRoutes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
          ? const Center(
        child: Text(
          'Saglabātu maršrutu vēl nav',
          style: TextStyle(fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        itemCount: _routes.length,
        itemBuilder: (context, index) {
          final route = _routes[index];

          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SurpriseRouteScreen(
                    route: route.pois,
                    start: route.start,
                    apiKey: '',
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.045),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(route.createdAt),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${route.pois.length} objekti',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    route.pois
                        .take(4)
                        .map((p) => p.name)
                        .join(' → '),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.25,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}