import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FB),
      appBar: AppBar(
        title: const Text('Kā lietot Surprise Ride'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: const [
          _HelpStep(
            icon: Icons.place,
            title: '1. Izvēlies sākumpunktu',
            text: 'Ieraksti pilsētu, izmanto savu atrašanās vietu vai izvēlies punktu kartē.',
          ),
          _HelpStep(
            icon: Icons.radar,
            title: '2. Iestati rādiusu',
            text: 'Izvēlies, cik tālu ap sākumpunktu app meklēs interesantus objektus.',
          ),
          _HelpStep(
            icon: Icons.travel_explore,
            title: '3. Atrodi POI',
            text: 'App sameklē apskates vietas un mēģina parādīt dažādus objektu tipus.',
          ),
          _HelpStep(
            icon: Icons.timer,
            title: '4. Izvēlies apmeklējuma laiku',
            text: 'Katram POI izvēlies 15, 45 vai 90 minūtes. No tā tiek aprēķināts kopējais maršruta laiks.',
          ),
          _HelpStep(
            icon: Icons.route,
            title: '5. Apskati maršrutu',
            text: 'Pārbaudi objektu secību, kopējo laiku un karti. Maršrutu vari atvērt arī Google Maps.',
          ),
          _HelpStep(
            icon: Icons.history,
            title: '6. Vēsture un apmeklētie objekti',
            text: 'Atzīmē apmeklētos POI un vēlāk vari paslēpt tos no jauniem piedāvājumiem.',
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
          Icon(icon, color: Color(0xFF6C63FF), size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  text,
                  style: TextStyle(
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