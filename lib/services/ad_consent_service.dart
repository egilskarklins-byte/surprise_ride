import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdConsentService {
  AdConsentService._();

  static bool canRequestAds = false;

  static Future<bool> gatherConsent() async {
    final completer = Completer<bool>();

    debugPrint('🔐 CONSENT: starting');

    try {
      final params = ConsentRequestParameters();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
            () {
          debugPrint('🔐 CONSENT: info updated');

          ConsentForm.loadAndShowConsentFormIfRequired(
                (FormError? formError) async {
              if (formError != null) {
                debugPrint(
                  '❌ CONSENT FORM ERROR: '
                      'code=${formError.errorCode} '
                      'message=${formError.message}',
                );

                canRequestAds = false;

                if (!completer.isCompleted) {
                  completer.complete(false);
                }
                return;
              }

              // Šis callback tiek izsaukts tikai pēc tam,
              // kad nepieciešamā consent forma ir pabeigta/aizvērta.
              canRequestAds =
              await ConsentInformation.instance.canRequestAds();

              debugPrint(
                '✅ CONSENT: form finished | '
                    'canRequestAds=$canRequestAds',
              );

              if (!completer.isCompleted) {
                completer.complete(canRequestAds);
              }
            },
          );
        },
            (FormError error) {
          debugPrint(
            '❌ CONSENT INFO ERROR: '
                'code=${error.errorCode} '
                'message=${error.message}',
          );

          canRequestAds = false;

          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );
    } catch (e) {
      debugPrint('❌ CONSENT EXCEPTION: $e');

      canRequestAds = false;

      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }

    return completer.future;
  }
}