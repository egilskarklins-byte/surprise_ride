import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final input = File('cities5000.txt');
  final output = File('assets/data/cities_world.json');

  if (!input.existsSync()) {
    print('❌ cities5000.txt nav atrasts');
    return;
  }

  final cities = <Map<String, dynamic>>[];

  final lines = await input.readAsLines();

  for (final line in lines) {
    if (line.trim().isEmpty) continue;

    final parts = line.split('\t');

    // GeoNames rindā jābūt vismaz 19 laukiem.
    if (parts.length < 19) continue;

    final name = parts[1].trim();
    final lat = double.tryParse(parts[4]);
    final lon = double.tryParse(parts[5]);
    final featureClass = parts[6];
    final featureCode = parts[7];
    final countryCode = parts[8];
    final population = int.tryParse(parts[14]) ?? 0;

    if (name.isEmpty || lat == null || lon == null) {
      continue;
    }

    // Atstājam tikai apdzīvotas vietas.
    if (featureClass != 'P') {
      continue;
    }

    // PPLX = pilsētas daļa/rajons.
    if (featureCode == 'PPLX') {
      continue;
    }

    cities.add({
      'n': name,
      'lat': lat,
      'lon': lon,
      'cc': countryCode,
      'p': population,
      't': featureCode,
    });
  }

  await output.writeAsString(
    jsonEncode(cities),
    flush: true,
  );

  final sizeMb =
      output.lengthSync() / (1024 * 1024);

  print('✅ Gatavs!');
  print('🏙️ Vietu skaits: ${cities.length}');
  print(
    '📦 cities_world.json: '
        '${sizeMb.toStringAsFixed(2)} MB',
  );
}