import 'package:flutter/material.dart';

import '../../services/app_language_service.dart';

class AlongRouteHelpScreen extends StatelessWidget {
  const AlongRouteHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBFB),
      appBar: AppBar(
        title: Text(
          AppLanguageService.tr(
            lv: 'Kā lietot Along Route',
            en: 'How to use Along Route',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          _HelpStep(
            icon: Icons.trip_origin,
            title: AppLanguageService.tr(
              lv: '1. Izvēlies sākumpunktu',
              en: '1. Choose a starting point',
            ),
            text: AppLanguageService.tr(
              lv: 'Ieraksti sākumpunktu, izmanto savu atrašanās vietu vai izvēlies punktu kartē.',
              en: 'Enter a starting point, use your current location, or choose a point on the map.',
            ),
          ),
          _HelpStep(
            icon: Icons.flag_outlined,
            title: AppLanguageService.tr(
              lv: '2. Izvēlies galamērķi',
              en: '2. Choose a destination',
            ),
            text: AppLanguageService.tr(
              lv: 'Norādi vietu, uz kuru vēlies doties. App izveidos A → B maršrutu.',
              en: 'Choose where you want to go. The app will create an A → B route.',
            ),
          ),
          _HelpStep(
            icon: Icons.travel_explore,
            title: AppLanguageService.tr(
              lv: '3. Atrodi vietas pa ceļam',
              en: '3. Find places along the route',
            ),
            text: AppLanguageService.tr(
              lv: 'App meklē interesantas apskates vietas maršruta tuvumā un parāda tās kartē.',
              en: 'The app searches for interesting places near your route and shows them on the map.',
            ),
          ),
          _HelpStep(
            icon: Icons.add_road,
            title: AppLanguageService.tr(
              lv: '4. Izvēlies vietas',
              en: '4. Choose places',
            ),
            text: AppLanguageService.tr(
              lv: 'Pievieno maršrutam vietas no kartes vai saraksta. Vari izvēlēties tikai tās, kuras vēlies apmeklēt.',
              en: 'Add places to your route from the map or list. Choose only the places you want to visit.',
            ),
          ),
          _HelpStep(
            icon: Icons.route,
            title: AppLanguageService.tr(
              lv: '5. Apskati maršruta priekšskatījumu',
              en: '5. Preview your route',
            ),
            text: AppLanguageService.tr(
              lv: 'Pārbaudi A → izvēlētās vietas → B maršrutu, kopējo attālumu un aptuveno braukšanas laiku.',
              en: 'Check the A → selected places → B route, total distance, and estimated driving time.',
            ),
          ),
          _HelpStep(
            icon: Icons.navigation,
            title: AppLanguageService.tr(
              lv: '6. Sāc navigāciju',
              en: '6. Start navigation',
            ),
            text: AppLanguageService.tr(
              lv: 'Kad maršruts gatavs, atver to Google Maps un sāc braucienu.',
              en: 'When the route is ready, open it in Google Maps and start your trip.',
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _HelpStep({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF10D9D1),
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}