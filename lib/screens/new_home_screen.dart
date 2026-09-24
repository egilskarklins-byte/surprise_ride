import 'dart:math';

import 'package:flutter/material.dart';

import '../services/app_language_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'surprise/along_route_input_screen.dart';
import 'surprise/input_screen.dart';
import '../widgets/admob_banner.dart';
import '../services/ad_consent_service.dart';
import 'package:geolocator/geolocator.dart';

import '../services/weather_direction_service.dart';
import 'weather_direction_map_screen.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen({super.key});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen>
    with TickerProviderStateMixin {
  bool _canRequestAds = false;

  late final AnimationController _guidePulseController;
  late final Animation<double> _guidePulseAnimation;
  late final AnimationController _weatherButtonTextController;
  bool _showRideModeGuide = false;
  @override
  void initState() {
    super.initState();
    _guidePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _guidePulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.07,
    ).animate(
      CurvedAnimation(
        parent: _guidePulseController,
        curve: Curves.easeInOut,
      ),
    );
    _weatherButtonTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingConsentForHomeAd();
    });
  }
  @override
  void dispose() {
    _guidePulseController.dispose();
    _weatherButtonTextController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingConsentForHomeAd() async {
    debugPrint('🏠 HOME: starting consent check');

    final canRequestAds = await AdConsentService.gatherConsent();

    debugPrint('🏠 HOME: consent finished | canRequestAds=$canRequestAds');

    if (!mounted || !canRequestAds) return;

    await MobileAds.instance.initialize();

    debugPrint('🏠 HOME: MobileAds initialized');

    if (!mounted) return;

    setState(() {
      _canRequestAds = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguageService.language,
      builder: (context, lang, _) {
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
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // ----------------------------------------------------
                            // VALODA
                            // ----------------------------------------------------
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () async {
                                  final lang = AppLanguageService.language.value;

                                  await AppLanguageService.setLanguage(
                                    lang == 'lv' ? 'en' : 'lv',
                                  );

                                },
                                child: Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.38),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.40),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.22),
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
                                          lv: 'EN',
                                          en: 'LV',
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
// KUR ŠODIEN BRAUKT?
// ====================================================
                            ScaleTransition(
                              scale: _showRideModeGuide
                                  ? const AlwaysStoppedAnimation<double>(1.0)
                                  : _guidePulseAnimation,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFB348FF).withValues(
                                          alpha: _showRideModeGuide
                                              ? 0.18
                                              : 0.25 +
                                              0.35 *
                                                  ((_guidePulseAnimation.value - 1.0) / 0.07),
                                        ),
                                        blurRadius: _showRideModeGuide
                                            ? 8
                                            : 12 +
                                            20 *
                                                ((_guidePulseAnimation.value - 1.0) / 0.07),
                                        spreadRadius: _showRideModeGuide
                                            ? 0
                                            : 1 +
                                            5 *
                                                ((_guidePulseAnimation.value - 1.0) / 0.07),
                                      ),
                                    ],
                                  ),
                                  child: SizedBox(
                                    height: 48,
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    // 1. Pārbaudām, vai telefonā vispār ir ieslēgta atrašanās vieta.
                                    final locationEnabled =
                                    await Geolocator.isLocationServiceEnabled();

                                    if (!locationEnabled) {
                                      if (!context.mounted) return;

                                      await showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: Text(
                                            AppLanguageService.tr(
                                              lv: '📍 Ieslēdz atrašanās vietu',
                                              en: '📍 Turn on location',
                                            ),
                                          ),
                                          content: Text(
                                            AppLanguageService.tr(
                                              lv: 'Lai atrastu virzienu ar labākajiem laikapstākļiem, Surprise Ride nepieciešama tava pašreizējā atrašanās vieta.',
                                              en: 'To find the direction with the best weather, Surprise Ride needs your current location.',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: Text(
                                                AppLanguageService.tr(
                                                  lv: 'Atcelt',
                                                  en: 'Cancel',
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                Navigator.pop(context);
                                                await Geolocator.openLocationSettings();
                                              },
                                              child: Text(
                                                AppLanguageService.tr(
                                                  lv: 'Ieslēgt',
                                                  en: 'Turn on',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      return;
                                    }

                                    // 2. Pārbaudām, vai lietotne jau drīkst izmantot atrašanās vietu.
                                    var permission = await Geolocator.checkPermission();

                                    if (permission == LocationPermission.denied) {
                                      if (!context.mounted) return;

                                      // Vispirms paskaidrojam, kāpēc atļauja nepieciešama.
                                      final allow = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: Text(
                                            AppLanguageService.tr(
                                              lv: '📍 Nepieciešama tava atrašanās vieta',
                                              en: '📍 Your location is needed',
                                            ),
                                          ),
                                          content: Text(
                                            AppLanguageService.tr(
                                              lv: 'Surprise Ride salīdzinās laikapstākļus 8 virzienos ap tevi, lai ieteiktu, kur šodien vislabāk doties.',
                                              en: 'Surprise Ride will compare the weather in 8 directions around you to suggest where to go today.',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: Text(
                                                AppLanguageService.tr(
                                                  lv: 'Atcelt',
                                                  en: 'Cancel',
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: Text(
                                                AppLanguageService.tr(
                                                  lv: 'Atļaut',
                                                  en: 'Allow',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (allow != true) return;

                                      permission = await Geolocator.requestPermission();
                                    }

                                    // 3. Ja lietotājs atļauju aizliedzis pavisam.
                                    if (permission == LocationPermission.deniedForever) {
                                      if (!context.mounted) return;

                                      await showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: Text(
                                            AppLanguageService.tr(
                                              lv: '📍 Atrašanās vieta nav atļauta',
                                              en: '📍 Location permission is disabled',
                                            ),
                                          ),
                                          content: Text(
                                            AppLanguageService.tr(
                                              lv: 'Atrašanās vietas atļauju vari ieslēgt Surprise Ride iestatījumos.',
                                              en: 'You can enable location permission in the Surprise Ride app settings.',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: Text(
                                                AppLanguageService.tr(
                                                  lv: 'Atcelt',
                                                  en: 'Cancel',
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                Navigator.pop(context);
                                                await Geolocator.openAppSettings();
                                              },
                                              child: Text(
                                                AppLanguageService.tr(
                                                  lv: 'Iestatījumi',
                                                  en: 'Settings',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      return;
                                    }

                                    if (permission == LocationPermission.denied) {
                                      return;
                                    }

                                    if (!context.mounted) return;

                                    // Loading logs
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => AlertDialog(
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(
                                              width: 42,
                                              height: 42,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 4,
                                                color: Color(0xFF7E57C2),
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            Text(
                                              AppLanguageService.tr(
                                                lv: 'Meklēju labāko virzienu...',
                                                en: 'Finding the best direction...',
                                              ),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              AppLanguageService.tr(
                                                lv: 'Salīdzinu laikapstākļus 8 virzienos ap tevi',
                                                en: 'Comparing weather in 8 directions around you',
                                              ),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );

                                    final position = await Geolocator.getCurrentPosition();

                                    final results =
                                    await WeatherDirectionService().getBestDirections(
                                      startLat: position.latitude,
                                      startLon: position.longitude,
                                      languageCode: AppLanguageService.language.value,
                                    );

                                    if (!context.mounted) return;

                                    Navigator.of(context, rootNavigator: true).pop();

                                    final best = results.first;

                                    final isLatvian =
                                    AppLanguageService.language.value
                                        .toLowerCase()
                                        .startsWith('lv');

                                    String directionName(String direction) {
                                      const lvNames = {
                                        'N': 'Ziemeļi',
                                        'NE': 'Ziemeļaustrumi',
                                        'E': 'Austrumi',
                                        'SE': 'Dienvidaustrumi',
                                        'S': 'Dienvidi',
                                        'SW': 'Dienvidrietumi',
                                        'W': 'Rietumi',
                                        'NW': 'Ziemeļrietumi',

                                        // Latviešu virzienu kodi
                                        'Z': 'Ziemeļi',
                                        'ZA': 'Ziemeļaustrumi',
                                        'A': 'Austrumi',
                                        'DA': 'Dienvidaustrumi',
                                        'D': 'Dienvidi',
                                        'DR': 'Dienvidrietumi',
                                        'R': 'Rietumi',
                                        'ZR': 'Ziemeļrietumi',
                                      };

                                      const enNames = {
                                        'N': 'North',
                                        'NE': 'Northeast',
                                        'E': 'East',
                                        'SE': 'Southeast',
                                        'S': 'South',
                                        'SW': 'Southwest',
                                        'W': 'West',
                                        'NW': 'Northwest',

                                        // Ja virziens jau pārveidots LV kodā
                                        'Z': 'North',
                                        'ZA': 'Northeast',
                                        'A': 'East',
                                        'DA': 'Southeast',
                                        'D': 'South',
                                        'DR': 'Southwest',
                                        'R': 'West',
                                        'ZR': 'Northwest',
                                      };

                                      return (isLatvian ? lvNames : enNames)[direction] ??
                                          direction;
                                    }

                                    String directionCode(String direction) {
                                      if (!isLatvian) return direction;

                                      const lvCodes = {
                                        'N': 'Z',
                                        'NE': 'ZA',
                                        'E': 'A',
                                        'SE': 'DA',
                                        'S': 'D',
                                        'SW': 'DR',
                                        'W': 'R',
                                        'NW': 'ZR',
                                      };

                                      return lvCodes[direction] ?? direction;
                                    }

                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text(
                                          AppLanguageService.tr(
                                            lv: '🌤️ Šodien dodies uz...',
                                            en: '🌤️ Today go towards...',
                                          ),
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${directionCode(best.direction)} '
                                                  '(${directionName(best.direction)})',
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),

                                            const SizedBox(height: 4),

                                            Text(
                                              AppLanguageService.tr(
                                                lv: '⭐ ${best.score.round()}/100 — lieliski ceļošanai',
                                                en: '⭐ ${best.score.round()}/100 — great for a trip',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),

                                            const SizedBox(height: 14),

                                            Text(
                                              best.reason,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                height: 1.4,
                                              ),
                                            ),

                                            const SizedBox(height: 14),

                                            Text(
                                              AppLanguageService.tr(
                                                lv: '✓ Šodien šajā virzienā ir vislabākie laikapstākļi izbraucienam.',
                                                en: '✓ Today\'s weather looks best in this direction.',
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),

                                            const SizedBox(height: 12),

                                            Text(
                                              AppLanguageService.tr(
                                                lv: 'Ieteikums balstīts uz laikapstākļiem aptuveni 100 km attālumā no tevis.',
                                                en: 'Recommendation based on weather about 100 km away from you.',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                height: 1.3,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(
                                              AppLanguageService.tr(
                                                lv: 'Aizvērt',
                                                en: 'Close',
                                              ),
                                            ),
                                          ),

                                          FilledButton.icon(
                                            onPressed: () async {
                                              Navigator.pop(context);

                                              final returnedFromWeather = await Navigator.push<bool>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => WeatherDirectionMapScreen(
                                                    startLat: position.latitude,
                                                    startLon: position.longitude,
                                                    results: results,
                                                  ),
                                                ),
                                              );

                                              if (!context.mounted) return;

                                              if (returnedFromWeather == true) {
                                                setState(() {
                                                  _showRideModeGuide = true;
                                                });

                                                _weatherButtonTextController.stop();
                                              }
                                            },
                                            icon: const Icon(Icons.map_outlined),
                                            label: Text(
                                              AppLanguageService.tr(
                                                lv: 'Parādīt kartē',
                                                en: 'Show on map',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } catch (e) {
                                    debugPrint('WEATHER DIRECTION ERROR: $e');
                                  }
                                },

                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  const Color(0xFF241634).withValues(alpha: 0.88),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                    side: BorderSide(
                                      color:
                                      const Color(0xFFB348FF).withValues(alpha: 0.75),
                                      width: 1.2,
                                    ),
                                  ),
                                ),

                                icon: const Icon(
                                  Icons.explore_outlined,
                                  size: 22,
                                ),

                                      label: _showRideModeGuide
                                          ? SizedBox(
                                        width: 180,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            AppLanguageService.tr(
                                              lv: 'Kur šodien braukt?',
                                              en: 'Where to drive today?',
                                            ),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      )
                                          : AnimatedBuilder(
                                        animation: _weatherButtonTextController,
                                        builder: (context, _) {
                                          final fullText = AppLanguageService.tr(
                                            lv: 'Kur šodien braukt?',
                                            en: 'Where to drive today?',
                                          );

                                          final progress = _weatherButtonTextController.value;

                                          // 0–75%: burti pakāpeniski un pārklājoties uzgaist.
                                          // 75–93%: viss teksts paliek pilnībā redzams.
                                          // 93–100%: īsa pauze pirms nākamā cikla.
                                          final typingProgress =
                                          progress < 0.75 ? progress / 0.75 : 1.0;

                                          final spans = <InlineSpan>[];

                                          for (int i = 0; i < fullText.length; i++) {
                                            double opacity;

                                            if (progress >= 0.75 && progress < 0.93) {
                                              opacity = 1.0;
                                            } else if (progress >= 0.93) {
                                              opacity = 0.0;
                                            } else {
                                              // Katrs nākamais burts sāk parādīties,
                                              // kamēr iepriekšējais vēl nav pilnībā uzgaisis.
                                              final letterStart = i / fullText.length;
                                              const fadeLength = 0.22;

                                              opacity =
                                                  ((typingProgress - letterStart) / fadeLength)
                                                      .clamp(0.0, 1.0);
                                            }

                                            spans.add(
                                              TextSpan(
                                                text: fullText[i],
                                                style: TextStyle(
                                                  color: Colors.white.withValues(
                                                    alpha: opacity,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          return SizedBox(
                                            width: 180,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text.rich(
                                                TextSpan(
                                                  children: spans,
                                                ),
                                                textAlign: TextAlign.left,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ), // ElevatedButton.icon
                                  ), // SizedBox
                                ), // Container
                            ), // ScaleTransitionaleTransition

                            SizedBox(height: isCompact ? 5 : 6),

                            // ====================================================
                            // ====================================================
                            // SURPRISE RIDE
                            // ====================================================
                            ScaleTransition(
                                scale: _showRideModeGuide
                                    ? _guidePulseAnimation
                                    : const AlwaysStoppedAnimation<double>(1.0),
                                child: SizedBox(
                                  height: cardHeight,
                                  child: _AdventureCard(
                                    onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SurpriseInputScreen(),
                                    ),
                                  );
                                },
                                imageAsset: 'lib/assets/home/surprise_card.png',
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
                            ), // ScaleTransition

                            SizedBox(height: isCompact ? 7 : 9),


                            /// ====================================================
// ALONG ROUTE
// ====================================================
                            ScaleTransition(
                                scale: _showRideModeGuide
                                    ? _guidePulseAnimation
                                    : const AlwaysStoppedAnimation<double>(1.0),
                                child: SizedBox(
                                  height: cardHeight,
                                  child: _AdventureCard(
                                    onTap: () {
                                      Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AlongRouteInputScreen(),
                                    ),
                                  );
                                },
                                imageAsset: 'lib/assets/home/along_route_card.png',
                                colors: const [
                                  Color(0xFF00A69E),
                                  Color(0xFF006C6A),
                                  Color(0xFF00383B),
                                ],
                                glowColor: const Color(0xFF10D9D1),
                                title: 'Along Route',
                                subtitle: AppLanguageService.tr(
                                  lv: 'A → B maršruts ar interesantām\nvietām pa ceļam',
                                  en: 'A → B route with interesting\nplaces along the way',
                                ),
                                  ),
                                ),
                            ), // ScaleTransition

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

                            const SizedBox(height: 8),


                            if (_canRequestAds)
                              const SizedBox(
                                height: 60,
                                child: Center(
                                  child: AdMobBanner(),
                                ),
                              ),

                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              );
            },
          ),
        );
      },
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
  final VoidCallback? onTap;

  final bool upcoming;
  final String? upcomingText;
  final String? developmentText;

  const _AdventureCard({
    required this.imageAsset,
    required this.colors,
    required this.glowColor,
    required this.title,
    required this.subtitle,
    this.onTap,
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
      onTap: widget.onTap,
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
