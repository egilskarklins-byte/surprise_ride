import 'dart:math';

import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class NewHomeScreen extends StatelessWidget {
  const NewHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05040A),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 760;

          final logoSize = isCompact ? 68.0 : 78.0;
          final cardHeight = isCompact ? 84.0 : 92.0;
          final titleSize = isCompact ? 27.0 : 30.0;

          return Stack(
            children: [
              // ============================================================
              // GALVENAIS FONA ATTĒLS
              // ============================================================
              Positioned.fill(
                child: Image.asset(
                  'lib/assets/home/home_background.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),

              // Tumšs pārklājums lasāmībai
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.18),
                        const Color(0xFF160722).withValues(alpha: 0.38),
                        const Color(0xFF05050A).withValues(alpha: 0.78),
                        const Color(0xFF020307).withValues(alpha: 0.96),
                      ],
                      stops: const [
                        0.0,
                        0.34,
                        0.72,
                        1.0,
                      ],
                    ),
                  ),
                ),
              ),

              // Violets atmosfēras glow
              Positioned(
                top: -120,
                left: -110,
                right: -110,
                child: IgnorePointer(
                  child: Container(
                    height: 420,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFB33CFF)
                              .withValues(alpha: 0.22),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Smalkas zvaigznes
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _StarPainter(),
                  ),
                ),
              ),

              // ============================================================
              // SATURS
              // ============================================================
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    isCompact ? 5 : 8,
                    18,
                    isCompact ? 7 : 11,
                  ),
                  child: Column(
                    children: [
                      // ----------------------------------------------------
                      // VALODA
                      // ----------------------------------------------------
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.38),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color:
                              Colors.white.withValues(alpha: 0.40),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.22),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.language,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppLanguageService.tr(
                                  lv: 'LV',
                                  en: 'EN',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: isCompact ? 4 : 7),

                      // ----------------------------------------------------
                      // SURPRISE RIDE LOGO
                      // ----------------------------------------------------
                      Container(
                        width: logoSize,
                        height: logoSize,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color:
                            Colors.white.withValues(alpha: 0.55),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC144FF)
                                  .withValues(alpha: 0.55),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: Image.asset(
                            'lib/assets/home/surprise_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) {
                              return Image.asset(
                                'assets/icons/app_icon.png',
                                fit: BoxFit.cover,
                              );
                            },
                          ),
                        ),
                      ),

                      SizedBox(height: isCompact ? 5 : 7),

                      // ----------------------------------------------------
                      // NOSAUKUMS
                      // ----------------------------------------------------
                      Text(
                        'SurpriseRide',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.7,
                          height: 1.0,
                          shadows: const [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isCompact ? 3 : 5),

                      Text(
                        AppLanguageService.tr(
                          lv: 'Atrodi negaidītu maršrutu',
                          en: 'Find an unexpected route',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                          Colors.white.withValues(alpha: 0.78),
                          fontSize: isCompact ? 13 : 14,
                          fontWeight: FontWeight.w500,
                          shadows: const [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 7,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isCompact ? 10 : 14),

                      // ----------------------------------------------------
                      // IZVĒLIES PIEDZĪVOJUMU
                      // ----------------------------------------------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '✦',
                            style: TextStyle(
                              color: Color(0xFFE15BFF),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              AppLanguageService.tr(
                                lv: 'Izvēlies piedzīvojumu',
                                en: 'Choose your adventure',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isCompact ? 15 : 17,
                                fontWeight: FontWeight.w900,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '✦',
                            style: TextStyle(
                              color: Color(0xFFE15BFF),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: isCompact ? 8 : 11),

                      // ====================================================
                      // SURPRISE RIDE
                      // ====================================================
                      SizedBox(
                        height: cardHeight,
                        child: _AdventureCard(
                          imageAsset:
                          'lib/assets/home/surprise_card.png',
                          colors: const [
                            Color(0xFF8D31E5),
                            Color(0xFF55199B),
                            Color(0xFF26073F),
                          ],
                          glowColor: const Color(0xFFB348FF),
                          title: 'Surprise Ride',
                          subtitle: AppLanguageService.tr(
                            lv: 'Aizbrauc nezinot,\nkas tevi sagaida',
                            en: 'Go without knowing\nwhat awaits you',
                          ),
                        ),
                      ),

                      SizedBox(height: isCompact ? 7 : 9),

                      // ====================================================
                      // ALONG ROUTE
                      // ====================================================
                      SizedBox(
                        height: cardHeight,
                        child: _AdventureCard(
                          imageAsset:
                          'lib/assets/home/along_route_card.png',
                          colors: const [
                            Color(0xFF00A69E),
                            Color(0xFF006C6A),
                            Color(0xFF00383B),
                          ],
                          glowColor: const Color(0xFF10D9D1),
                          title: 'Along Route',
                          subtitle: AppLanguageService.tr(
                            lv:
                            'A → B maršruts ar interesantām\nvietām pa ceļam',
                            en:
                            'A → B route with interesting\nplaces along the way',
                          ),
                        ),
                      ),

                      SizedBox(height: isCompact ? 7 : 9),

                      // ====================================================
                      // FUNWEATHER
                      // ====================================================
                      SizedBox(
                        height: cardHeight,
                        child: _AdventureCard(
                          imageAsset:
                          'lib/assets/home/funweather_card.png',
                          colors: const [
                            Color(0xFF168FD3),
                            Color(0xFF075D9D),
                            Color(0xFF052D56),
                          ],
                          glowColor: const Color(0xFF25AFFF),
                          title: 'FunWeather Ride',
                          subtitle: AppLanguageService.tr(
                            lv:
                            'Vairāku dienu ceļojumi\npēc laikapstākļiem',
                            en:
                            'Multi-day trips\nbased on the weather',
                          ),
                          upcoming: true,
                          upcomingText: AppLanguageService.tr(
                            lv: 'DRĪZUMĀ',
                            en: 'SOON',
                          ),
                          developmentText: AppLanguageService.tr(
                            lv: 'Izstrādē',
                            en: 'In development',
                          ),
                        ),
                      ),

                      const Spacer(),

                      // ----------------------------------------------------
                      // APAKŠĒJAIS ATDALĪTĀJS
                      // ----------------------------------------------------
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color:
                              Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          const Padding(
                            padding:
                            EdgeInsets.symmetric(horizontal: 9),
                            child: Text(
                              '✦',
                              style: TextStyle(
                                color: Color(0xFFD64EFF),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color:
                              Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: isCompact ? 7 : 9),

                      // ----------------------------------------------------
                      // SETTINGS / HISTORY
                      // ----------------------------------------------------
                      SizedBox(
                        height: isCompact ? 48 : 53,
                        child: Row(
                          children: [
                            Expanded(
                              child: _BottomAction(
                                icon: Icons.settings_outlined,
                                label: AppLanguageService.tr(
                                  lv: 'Iestatījumi',
                                  en: 'Settings',
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 34,
                              color:
                              Colors.white.withValues(alpha: 0.22),
                            ),
                            Expanded(
                              child: _BottomAction(
                                icon: Icons.history_rounded,
                                label: AppLanguageService.tr(
                                  lv: 'Vēsture',
                                  en: 'History',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================================================
// PIEDZĪVOJUMA KARTĪTE
// ==========================================================================

class _AdventureCard extends StatefulWidget {
  final String imageAsset;
  final List<Color> colors;
  final Color glowColor;
  final String title;
  final String subtitle;

  final bool upcoming;
  final String? upcomingText;
  final String? developmentText;

  const _AdventureCard({
    required this.imageAsset,
    required this.colors,
    required this.glowColor,
    required this.title,
    required this.subtitle,
    this.upcoming = false,
    this.upcomingText,
    this.developmentText,
  });

  @override
  State<_AdventureCard> createState() => _AdventureCardState();
}

class _AdventureCardState extends State<_AdventureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.glowColor.withValues(alpha: 0.85),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.22),
                blurRadius: 17,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // =====================================================
                    // BILDE PA VISU KARTĪTI
                    //
                    // BoxFit.fill šeit ir speciāli:
                    // visa bilde ir redzama un aizpilda visu gareno pogu.
                    // Nekas netiek nogriezts ārpus kartītes.
                    // =====================================================
                    Image.asset(
                      widget.imageAsset,
                      fit: BoxFit.fill,
                    ),

                    // Viegls tumšais pārklājums pa visu kartīti
                    Container(
                      color: Colors.black.withValues(alpha: 0.12),
                    ),

                    // =====================================================
                    // GRADIENTS TEKSTA LASĀMĪBAI
                    // Kreisajā pusē bilde paliek spilgtāka,
                    // pa labi kļūst tumšāka zem teksta.
                    // =====================================================
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.18),
                            widget.colors.last.withValues(alpha: 0.72),
                            widget.colors.last.withValues(alpha: 0.92),
                          ],
                          stops: const [
                            0.0,
                            0.34,
                            0.62,
                            1.0,
                          ],
                        ),
                      ),
                    ),

                    // Neliels krāsas tonis, lai visas kartītes
                    // saglabā savu violeto / zaļo / zilo identitāti
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.colors.first.withValues(alpha: 0.10),
                            Colors.transparent,
                            widget.colors.last.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                    ),

                    // =====================================================
                    // TEKSTS
                    // Attēls turpinās arī zem teksta.
                    // Teksts sākas ~39% no kartītes platuma.
                    // =====================================================
                    Padding(
                      padding: EdgeInsets.only(
                        left: constraints.maxWidth * 0.39,
                        right: 8,
                        top: 7,
                        bottom: 7,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.title,
                                        maxLines: 1,
                                        overflow:
                                        TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15.5,
                                          fontWeight:
                                          FontWeight.w900,
                                          height: 1.0,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black,
                                              blurRadius: 7,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    if (widget.upcoming) ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        padding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFFFB82E,
                                          ),
                                          borderRadius:
                                          BorderRadius.circular(11),
                                        ),
                                        child: Text(
                                          widget.upcomingText ??
                                              'DRĪZUMĀ',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 7.5,
                                            fontWeight:
                                            FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                const SizedBox(height: 5),

                                Text(
                                  widget.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white
                                        .withValues(alpha: 0.88),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.15,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 3),

                          SizedBox(
                            width: 30,
                            child: Column(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white,
                                  size: 27,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),

                                if (widget.upcoming)
                                  Padding(
                                    padding:
                                    const EdgeInsets.only(top: 2),
                                    child: Text(
                                      widget.developmentText ??
                                          'Izstrādē',
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.78),
                                        fontSize: 6.5,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 5,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// APAKŠĒJĀ POGA
// ==========================================================================

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BottomAction({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 25,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ==========================================================================
// ZVAIGZNES
// ==========================================================================

class _StarPainter extends CustomPainter {
  const _StarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    final paint = Paint();

    for (var i = 0; i < 45; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.48;

      final radius =
          0.35 + random.nextDouble() * 1.15;

      final opacity =
          0.10 + random.nextDouble() * 0.38;

      paint.color =
          Colors.white.withValues(alpha: opacity);

      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) =>
      false;
}