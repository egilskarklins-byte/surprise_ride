
class WeatherDay {
  final DateTime date;
  final double tempC;
  final double windMs;
  final double rainMm;
  final String description;

  // Papildu dati FunWeather vērtēšanai.
  final int weatherCode;
  final double precipitationProbability;
  final double windGustMs;
  final double cloudCover;

  const WeatherDay({
    required this.date,
    required this.tempC,
    required this.windMs,
    required this.rainMm,
    required this.description,
    this.weatherCode = -1,
    this.precipitationProbability = 0,
    this.windGustMs = 0,
    this.cloudCover = 0,
  });

  bool get isRainy => rainMm >= 1.0;
  bool get isStormy => windMs >= 12.0;
  bool get isCold => tempC <= 2.0;

  bool get isFoggy => weatherCode == 45 || weatherCode == 48;

  bool get isFreezingRain =>
      weatherCode == 56 ||
          weatherCode == 57 ||
          weatherCode == 66 ||
          weatherCode == 67;

  bool get isSnowy =>
      (weatherCode >= 71 && weatherCode <= 77) ||
          weatherCode == 85 ||
          weatherCode == 86;

  bool get isThunderstorm => weatherCode >= 95 && weatherCode <= 99;
}
