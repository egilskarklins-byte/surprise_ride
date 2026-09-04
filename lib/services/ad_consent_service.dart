import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdConsentService {
  AdConsentService._();

  static bool canRequestAds = false;

  static Future<bool> gatherConsent() async {
    final completer = Completer<bool>();

    try {
      final params = ConsentRequestParameters();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
            () {
          try {
            ConsentForm.loadAndShowConsentFormIfRequired(
                  (FormError? formError) async {
                if (formError != null) {
                  canRequestAds = false;

                  if (!completer.isCompleted) {
                    completer.complete(false);
                  }
                  return;
                }

                canRequestAds =
                await ConsentInformation.instance.canRequestAds();

                if (!completer.isCompleted) {
                  completer.complete(canRequestAds);
                }
              },
            );
          } catch (_) {
            canRequestAds = false;

            if (!completer.isCompleted) {
              completer.complete(false);
            }
          }
        },
            (FormError error) {
          canRequestAds = false;

          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );
    } catch (_) {
      canRequestAds = false;

      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        canRequestAds = false;
        return false;
      },
    );
  }
}
