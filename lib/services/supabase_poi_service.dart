import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/geo.dart';
import '../models/poi.dart';

class SupabasePoiService {
  SupabasePoiService._();

  static final SupabasePoiService instance = SupabasePoiService._();

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Poi>> fetchPois() async {
    final rows = await _client
        .from('pois')
        .select()
        .eq('is_active', true);

    return rows.map<Poi>((row) {
      final rawCategories = row['categories'];

      final categories = <PoiCategory>{};

      if (rawCategories is List) {
        for (final value in rawCategories) {
          final name = value.toString();

          for (final category in PoiCategory.values) {
            if (category.name == name) {
              categories.add(category);
              break;
            }
          }
        }
      }

      return Poi(
        id: row['id'].toString(),
        name: row['name'].toString(),
        location: LatLon(
          (row['lat'] as num).toDouble(),
          (row['lon'] as num).toDouble(),
        ),
        visitMinutes:
        (row['visit_minutes'] as num?)?.toInt() ?? 30,
        shortDescription: row['short_description'] as String?,
        categories: categories.isEmpty
            ? const {PoiCategory.mustSee}
            : categories,
      );
    }).toList();
  }
  Future<void> savePois(Iterable<Poi> pois) async {
    if (pois.isEmpty) return;

    final rows = pois.map((poi) {
      return {
        'id': poi.id,
        'name': poi.name,
        'lat': poi.location.lat,
        'lon': poi.location.lon,
        'visit_minutes': poi.visitMinutes,
        'short_description': poi.shortDescription,
        'categories': poi.categories
            .map((category) => category.name)
            .toList(),
        'is_active': true,
      };
    }).toList();

    await _client
        .from('pois')
        .upsert(
      rows,
      onConflict: 'id',
    );
  }
}