import 'package:flutter/material.dart';

import '../../services/app_language_service.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FB),
      appBar: AppBar(
        title: Text(
          AppLanguageService.tr(
            lv: 'Kā lietot Surprise Ride',
            en: 'How to use Surprise Ride',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          _HelpStep(
            icon: Icons.place,
            title: AppLanguageService.tr(
              lv: '1. Izvēlies sākumpunktu',
              en: '1. Choose a starting point',
            ),
            text: AppLanguageService.tr(
              lv: 'Ieraksti pilsētu, izmanto savu atrašanās vietu vai izvēlies punktu kartē.',
              en: 'Enter a city, use your current location, or choose a point on the map.',
            ),
          ),
          _HelpStep(
            icon: Icons.radar,
            title: AppLanguageService.tr(
              lv: '2. Iestati rādiusu',
              en: '2. Set the radius',
            ),
            text: AppLanguageService.tr(
              lv: 'Izvēlies, cik tālu ap sākumpunktu app meklēs interesantus objektus.',
              en: 'Choose how far around the starting point the app should search for interesting places.',
            ),
          ),
          _HelpStep(
            icon: Icons.travel_explore,
            title: AppLanguageService.tr(
              lv: '3. Atrodi POI',
              en: '3. Find POIs',
            ),
            text: AppLanguageService.tr(
              lv: 'App sameklē apskates vietas un mēģina parādīt dažādus objektu tipus.',
              en: 'The app finds places to visit and tries to show different types of POIs.',
            ),
          ),
          _HelpStep(
            icon: Icons.timer,
            title: AppLanguageService.tr(
              lv: '4. Izvēlies apmeklējuma laiku',
              en: '4. Choose visit time',
            ),
            text: AppLanguageService.tr(
              lv: 'Katram POI izvēlies 15, 45 vai 90 minūtes. No tā tiek aprēķināts kopējais maršruta laiks.',
              en: 'Choose 15, 45, or 90 minutes for each POI. This is used to calculate the total route time.',
            ),
          ),
          _HelpStep(
            icon: Icons.route,
            title: AppLanguageService.tr(
              lv: '5. Apskati maršrutu',
              en: '5. Preview the route',
            ),
            text: AppLanguageService.tr(
              lv: 'Pārbaudi objektu secību, kopējo laiku un karti. Maršrutu vari atvērt arī Google Maps.',
              en: 'Check the POI order, total time, and map. You can also open the route in Google Maps.',
            ),
          ),
          _HelpStep(
            icon: Icons.history,
            title: AppLanguageService.tr(
              lv: '6. Vēsture un apmeklētie objekti',
              en: '6. History and visited places',
            ),
            text: AppLanguageService.tr(
              lv: 'Atzīmē apmeklētos POI un vēlāk vari paslēpt tos no jauniem piedāvājumiem.',
              en: 'Mark visited POIs and later hide them from new suggestions.',
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
          const SizedBox(width: 0),
          Icon(icon, color: const Color(0xFF6C63FF), size: 28),
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