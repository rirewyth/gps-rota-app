import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:math' as Math;
import 'dart:developer' as dev;

class LocationResult {
  final String name;
  final double lat;
  final double lng;
  final String admin1;
  final String country;

  LocationResult({
    required this.name,
    required this.lat,
    required this.lng,
    required this.admin1,
    required this.country,
  });
}

class AdvancedAlert {
  final String title;
  final String message;
  final String severity; // 'info', 'warning', 'critical'
  final IconData icon;

  AdvancedAlert({
    required this.title,
    required this.message,
    required this.severity,
    required this.icon,
  });
}

class WeatherAlertInfo {
  final bool isHazardous;
  final String title;
  final String description;
  final double temperature;
  final double windSpeed;
  final double windDirection;
  final double? pressure;
  final double? seaLevelPressure;
  final double? humidity;
  final double? dewPoint;
  final String? hazardProximity;
  final int weatherCode;
  final double? uvIndex;
  final double? cloudCover;
  final double? visibility;
  final double? precipitation;
  final double? precipitationProbability;
  final double? snowfall;
  final bool isLoading;

  WeatherAlertInfo({
    required this.isHazardous,
    required this.title,
    required this.description,
    required this.temperature,
    required this.windSpeed,
    required this.windDirection,
    this.pressure,
    this.seaLevelPressure,
    this.humidity,
    this.hazardProximity,
    this.weatherCode = 0,
    this.uvIndex,
    this.cloudCover,
    this.visibility,
    this.precipitation,
    this.precipitationProbability,
    this.snowfall,
    this.dewPoint,
    this.isLoading = false,
  });
}

class HourlyWeather {
  final DateTime time;
  final double temperature;
  final double windSpeed;
  final int weatherCode;
  final double precipitation;
  final double humidity;
  final double dewPoint;

  HourlyWeather({
    required this.time,
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
    required this.precipitation,
    required this.humidity,
    required this.dewPoint,
  });
}

class DailyWeather {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final int weatherCode;
  final double windSpeedMax;
  final double precipitationSum;
  final double snowfallSum;
  final double uvIndexMax;

  DailyWeather({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.weatherCode,
    required this.windSpeedMax,
    required this.precipitationSum,
    required this.snowfallSum,
    required this.uvIndexMax,
  });
}

class MountainRiskIndex {
  final int frostbiteRisk; // 0-100
  final int lightningRisk;  // 0-100
  final int avalancheRisk;  // 0-100
  final int windRisk;       // 0-100
  final int overallRisk;    // 0-100
  final double windChill;   // feels-like temp
  final String overallLabel;
  final String overallColor; // 'green' | 'orange' | 'red'

  MountainRiskIndex({
    required this.frostbiteRisk,
    required this.lightningRisk,
    required this.avalancheRisk,
    required this.windRisk,
    required this.overallRisk,
    required this.windChill,
    required this.overallLabel,
    required this.overallColor,
  });
}

class FullWeatherData {
  final WeatherAlertInfo current;
  final List<HourlyWeather> hourly; // Next 24h
  final List<DailyWeather> daily;   // 7 days
  final MountainRiskIndex risks;
  final List<AdvancedAlert> advancedAlerts;

  FullWeatherData({
    required this.current,
    required this.hourly,
    required this.daily,
    required this.risks,
    this.advancedAlerts = const [],
  });
}

class WeatherService {
  static final Dio _dio = Dio();
  static const String stormRiskLow = "DÜŞÜK";
  static const String stormRiskHigh = "YÜKSEK";
  static const String loadingState = "YÜKLENİYOR...";

  // Existing simple method (still used by home screen)
  static Future<dynamic> checkStormRisk(double lat, double lng) async {
    try {
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,wind_speed_10m,wind_direction_10m,weather_code,snowfall,surface_pressure,pressure_msl,relative_humidity_2m,dew_point_2m,uv_index,cloud_cover,visibility,precipitation,precipitation_probability';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final current = response.data['current'];
        if (current == null) return null;

        final double temp = (current['temperature_2m'] ?? 0.0).toDouble();
        final double wind = (current['wind_speed_10m'] ?? 0.0).toDouble();
        final double windDir = (current['wind_direction_10m'] ?? 0.0).toDouble();
        final int wCode = (current['weather_code'] ?? 0).toInt();
        final double pressure = (current['surface_pressure'] ?? 1013.25).toDouble();
        final double seaLevelPressure = (current['pressure_msl'] ?? 1013.25).toDouble();
        final double humidity = (current['relative_humidity_2m'] ?? 50.0).toDouble();
        final double? dewPoint = current['dew_point_2m']?.toDouble();
        final double? uvIndex = current['uv_index']?.toDouble();
        final double? cloudCover = current['cloud_cover']?.toDouble();
        final double? visibility = current['visibility']?.toDouble();
        final double? precip = current['precipitation']?.toDouble();
        final double? precipProb = current['precipitation_probability']?.toDouble();
        final double? snowfall = current['snowfall']?.toDouble();

        bool isStorm = false;
        String alertTitle = 'GÜVENLİ METEROLOJİ';
        String alertDesc = 'Hava yürüyüş ve operasyon için uygun.';
        String? proximity;

        if ([71, 73, 75, 77, 85, 86].contains(wCode)) {
          isStorm = true;
          alertTitle = 'ÇIĞ VE KAR UYARISI';
          alertDesc = 'Yoğun kar yağışı tespit edildi. Görüş mesafesi sıfıra inebilir ve çığ riski artmıştır!';
          proximity = 'Yaklaşık 5-10 km mesafede aktif kar kütlesi.';
        } else if ([95, 96, 99].contains(wCode)) {
          isStorm = true;
          alertTitle = 'FIRTINA / ŞİMŞEK UYARISI';
          alertDesc = 'Bölgede kritik seviyede şimşek aktivitesi ve fırtına uyarısı var. Derhal güvenli alana intikal edin.';
          proximity = 'KRİTİK: < 2 km mesafede elektriksel aktivite.';
        } else if (wind > 45.0) {
          isStorm = true;
          alertTitle = 'ŞİDDETLİ RÜZGAR';
          alertDesc = 'Rüzgar hızı tehlikeli seviyede ($wind km/h). Denge kaybı yaşanabilir!';
        } else if (temp < -10.0) {
          isStorm = true;
          alertTitle = 'HİPOTERMİ RİSKİ';
          alertDesc = 'Hava sıcaklığı ekstrem düzeyde ($temp °C). Isı kaybına karşı acil önlem alın.';
        }

        return WeatherAlertInfo(
          isHazardous: isStorm,
          title: alertTitle,
          description: alertDesc,
          temperature: temp,
          windSpeed: wind,
          windDirection: windDir,
          pressure: pressure,
          seaLevelPressure: seaLevelPressure,
          humidity: humidity,
          hazardProximity: proximity,
          weatherCode: wCode,
          uvIndex: uvIndex,
          cloudCover: cloudCover,
          visibility: visibility,
          precipitation: precip,
          precipitationProbability: precipProb,
          snowfall: snowfall,
          dewPoint: dewPoint,
          isLoading: false,
        );
      }
      return null;
    } catch (e) {
      dev.log("Storm Risk Error: $e");
      return WeatherAlertInfo(
        isHazardous: false,
        title: loadingState,
        description: 'Hava durumu verileri alınamıyor.',
        temperature: 0,
        windSpeed: 0,
        windDirection: 0,
        isLoading: true,
      );
    }
  }

  // Premium full weather data with hourly + daily + mountain risk index
  static Future<FullWeatherData?> getFullWeatherData(double lat, double lng, {double altitudeMeters = 0}) async {
    try {
      final url = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$lat',
        'longitude': '$lng',
        'current': 'temperature_2m,wind_speed_10m,wind_direction_10m,weather_code,snowfall,surface_pressure,pressure_msl,relative_humidity_2m,dew_point_2m,uv_index,cloud_cover,visibility,precipitation,precipitation_probability',
        'hourly': 'temperature_2m,wind_speed_10m,weather_code,precipitation,precipitation_probability,relative_humidity_2m,visibility,surface_pressure,dew_point_2m',
        'daily': 'temperature_2m_min,temperature_2m_max,weather_code,wind_speed_10m_max,precipitation_sum,snowfall_sum,uv_index_max,sunrise,sunset',
        'wind_speed_unit': 'kmh',
        'timezone': 'auto',
        'forecast_days': '7',
        'past_hours': '24',
      }).toString();

      final response = await _dio.get(url);

      if (response.statusCode != 200 || response.data == null) return null;

      final data = response.data;

      // ── Current ──────────────────────────────────────────────
      final cur = data['current'];
      final WeatherAlertInfo currentAlert = await checkStormRisk(lat, lng) ??
          WeatherAlertInfo(
            isHazardous: false,
            title: 'GÜVENLİ',
            description: 'Hava durumu normal.',
            temperature: (cur['temperature_2m'] ?? 0.0).toDouble(),
            windSpeed: (cur['wind_speed_10m'] ?? 0.0).toDouble(),
            windDirection: (cur['wind_direction_10m'] ?? 0.0).toDouble(),
          );

      // ── Hourly (next 24h) ─────────────────────────────────────
      final hourlyData = data['hourly'];
      final List<HourlyWeather> hourlyList = [];
      if (hourlyData != null) {
        final times = hourlyData['time'] as List;
        final now = DateTime.now();
        for (int i = 0; i < times.length && hourlyList.length < 24; i++) {
          final dt = DateTime.parse(times[i]);
          if (dt.isBefore(now.subtract(const Duration(hours: 6)))) continue;
          hourlyList.add(HourlyWeather(
            time: dt,
            temperature: (hourlyData['temperature_2m'][i] ?? 0.0).toDouble(),
            windSpeed: (hourlyData['wind_speed_10m'][i] ?? 0.0).toDouble(),
            weatherCode: (hourlyData['weather_code'][i] ?? 0).toInt(),
            precipitation: (hourlyData['precipitation'][i] ?? 0.0).toDouble(),
            humidity: (hourlyData['relative_humidity_2m'][i] ?? 50.0).toDouble(),
            dewPoint: (hourlyData['dew_point_2m'][i] ?? 0.0).toDouble(),
          ));
        }
      }

      // ── Daily (7 days) ────────────────────────────────────────
      final dailyData = data['daily'];
      final List<DailyWeather> dailyList = [];
      if (dailyData != null) {
        final times = dailyData['time'] as List;
        for (int i = 0; i < times.length; i++) {
          dailyList.add(DailyWeather(
            date: DateTime.parse(times[i]),
            tempMin: (dailyData['temperature_2m_min'][i] ?? 0.0).toDouble(),
            tempMax: (dailyData['temperature_2m_max'][i] ?? 0.0).toDouble(),
            weatherCode: (dailyData['weather_code'][i] ?? 0).toInt(),
            windSpeedMax: (dailyData['wind_speed_10m_max'][i] ?? 0.0).toDouble(),
            precipitationSum: (dailyData['precipitation_sum'][i] ?? 0.0).toDouble(),
            snowfallSum: (dailyData['snowfall_sum'][i] ?? 0.0).toDouble(),
            uvIndexMax: (dailyData['uv_index_max'][i] ?? 0.0).toDouble(),
          ));
        }
      }

      // ── Mountain Risk Index ────────────────────────────────────
      final double temp = currentAlert.temperature;
      final double wind = currentAlert.windSpeed;
      final int wCode = currentAlert.weatherCode;
      final double humidity = currentAlert.humidity ?? 50;

      // Wind chill (Steadman / North American formula)
      double windChill = temp;
      if (wind > 4.8 && temp < 10) {
        final v016 = Math.pow(wind.clamp(0.1, double.infinity), 0.16).toDouble();
        windChill = 13.12 + (0.6215 * temp) - (11.37 * v016) + (0.3965 * temp * v016);
      }

      // Frostbite risk (based on windchill)
      int frostbiteRisk = 0;
      if (windChill < -27) frostbiteRisk = 100;
      else if (windChill < -20) frostbiteRisk = 80;
      else if (windChill < -10) frostbiteRisk = 50;
      else if (windChill < 0) frostbiteRisk = 20;

      // Lightning risk (thunderstorm codes)
      int lightningRisk = 0;
      if ([95, 96, 99].contains(wCode)) lightningRisk = 100;
      else if ([80, 81, 82].contains(wCode)) lightningRisk = 40;
      else if (humidity > 85 && wCode > 50) lightningRisk = 30;

      // Avalanche risk (snow + wind)
      int avalancheRisk = 0;
      final snowfall = currentAlert.snowfall ?? 0;
      if ([71, 73, 75, 77, 85, 86].contains(wCode)) {
        avalancheRisk = wind > 30 ? 90 : 60;
      } else if (snowfall > 0) {
        avalancheRisk = wind > 40 ? 70 : 30;
      } else if (altitudeMeters > 2000 && [61, 63, 65].contains(wCode)) {
        avalancheRisk = 40; // Rain on snow at high altitude
      }

      // Wind risk
      int windRisk = 0;
      if (wind > 80) windRisk = 100;
      else if (wind > 60) windRisk = 80;
      else if (wind > 45) windRisk = 60;
      else if (wind > 30) windRisk = 30;

      // Overall risk score
      final overallRisk = ([frostbiteRisk, lightningRisk, avalancheRisk, windRisk].reduce((a, b) => a > b ? a : b));

      String overallLabel;
      String overallColor;
      if (overallRisk >= 70) {
        overallLabel = 'KRİTİK TEHLİKE';
        overallColor = 'red';
      } else if (overallRisk >= 40) {
        overallLabel = 'DİKKATLİ OL';
        overallColor = 'orange';
      } else {
        overallLabel = 'GÜVENLİ BÖLGE';
        overallColor = 'green';
      }

      final risks = MountainRiskIndex(
        frostbiteRisk: frostbiteRisk,
        lightningRisk: lightningRisk,
        avalancheRisk: avalancheRisk,
        windRisk: windRisk,
        overallRisk: overallRisk,
        windChill: windChill,
        overallLabel: overallLabel,
        overallColor: overallColor,
      );


      // ── Advanced Alerts (Trend Analysis) ────────────────────────
      final List<AdvancedAlert> advancedAlerts = [];
      if (hourlyData != null) {
        final times = (hourlyData['time'] as List).map((t) => DateTime.parse(t)).toList();
        final temps = (hourlyData['temperature_2m'] as List).map((v) => (v ?? 0.0).toDouble()).toList();
        final pressures = (hourlyData['surface_pressure'] as List).map((v) => (v ?? 1013.25).toDouble()).toList();
        final winds = (hourlyData['wind_speed_10m'] as List).map((v) => (v ?? 0.0).toDouble()).toList();

        // Find current index in hourly arrays
        int curIdx = -1;
        final now = DateTime.now();
        for (int i = 0; i < times.length; i++) {
          if (times[i].year == now.year && times[i].month == now.month && times[i].day == now.day && times[i].hour == now.hour) {
            curIdx = i;
            break;
          }
        }

        if (curIdx != -1) {
          double pDiff3 = curIdx >= 3 ? pressures[curIdx] - pressures[curIdx - 3] : 0;
          double pDiff6 = curIdx >= 6 ? pressures[curIdx] - pressures[curIdx - 6] : 0;
          double pDiff12 = curIdx >= 12 ? pressures[curIdx] - pressures[curIdx - 12] : 0;
          double tDiff1 = curIdx >= 1 ? temps[curIdx] - temps[curIdx - 1] : 0;

          // 1. Convection / CB
          if (pDiff3 <= -2 && tDiff1 <= -4 && (currentAlert.dewPoint ?? 0) >= 18) {
            advancedAlerts.add(AdvancedAlert(
              title: 'KUVVETLİ KONVEKSİYON (CB)',
              message: 'Basınçta hızlı düşüş ve ani sıcaklık kaybı. Gök gürültülü sağanak ve dolu riski yüksek.',
              severity: 'critical',
              icon: Icons.thunderstorm,
            ));
          }

          // 2. Cold Front
          if (pDiff3 <= -3 && tDiff1 <= -5) {
            advancedAlerts.add(AdvancedAlert(
              title: 'SOĞUK CEPHE GEÇİŞİ',
              message: 'Klasik soğuk cephe imzası: Şiddetli rüzgar ve ani yağış geçişi bekleniyor.',
              severity: 'critical',
              icon: Icons.ac_unit,
            ));
          }

          // 3. Fog
          double tTdDiff = temp - (currentAlert.dewPoint ?? -999);
          if (wind < 10 && tTdDiff >= 0 && tTdDiff <= 2 && humidity > 90) {
            advancedAlerts.add(AdvancedAlert(
              title: 'YOĞUN SİS UYARISI',
              message: 'Düşük rüzgar ve yüksek nem: Görüş mesafesi hızla azalabilir (T-Td <= 2°C).',
              severity: 'warning',
              icon: Icons.visibility_off,
            ));
          }

          // 4. Lodos / Storm
          if (pDiff6 <= -6 && wind > 30) {
            advancedAlerts.add(AdvancedAlert(
              title: 'KUVVETLİ LODOS / FIRTINA',
              message: 'Derin siklon sinyali. Basınç 6 saatte 6 hPa\'dan fazla düştü.',
              severity: 'critical',
              icon: Icons.air,
            ));
          }

          // 5. Snow
          if (temp <= 2 && (currentAlert.dewPoint ?? 5) <= 1 && humidity > 80) {
            advancedAlerts.add(AdvancedAlert(
              title: 'GÜÇLÜ KAR SİNYALİ',
              message: 'Sıcaklık ve çiy noktası kar değerlerinde. Yağışın kara dönmesi bekleniyor.',
              severity: 'warning',
              icon: Icons.ac_unit,
            ));
          }

          // 6. Frost
          if (temp <= 0 && wind < 10) {
            advancedAlerts.add(AdvancedAlert(
              title: 'ZİRAİ DON RİSKİ',
              message: 'Sakin rüzgar ve sıfırın altındaki sıcaklık: Radyasyon donu bekleniyor.',
              severity: 'warning',
              icon: Icons.warning_amber_rounded,
            ));
          }

          // 7. Medicane
          if (pDiff12 <= -8 && wind > 60) {
            advancedAlerts.add(AdvancedAlert(
              title: 'MEDICANE / TROPİK SİSTEM',
              message: 'Ekstrem basınç düşüşü ve fırtına. Akdeniz benzeri tropik sistem yaklaşımı.',
              severity: 'critical',
              icon: Icons.cyclone,
            ));
          }
        }
      }

      return FullWeatherData(
        current: currentAlert,
        hourly: hourlyList,
        daily: dailyList,
        risks: risks,
        advancedAlerts: advancedAlerts,
      );
    } catch (e) {
      debugPrint('Full weather fetch error: $e');
      return null;
    }
  }

  // WMO code to emoji + label
  static String weatherEmoji(int code) {
    if (code == 0) return '☀️';
    if (code <= 2) return '🌤️';
    if (code <= 3) return '☁️';
    if (code <= 49) return '🌫️';
    if (code <= 57) return '🌧️';
    if (code <= 65) return '🌧️';
    if (code <= 77) return '❄️';
    if (code <= 82) return '🌧️';
    if (code <= 86) return '🌨️';
    if (code <= 99) return '⛈️';
    return '🌡️';
  }

  static String weatherLabel(int code) {
    if (code == 0) return 'Açık';
    if (code <= 2) return 'Az Bulutlu';
    if (code <= 3) return 'Bulutlu';
    if (code <= 49) return 'Sisli';
    if (code <= 57) return 'Çiseleyen Yağmur';
    if (code <= 65) return 'Yağmurlu';
    if (code <= 71) return 'Az Karlı';
    if (code <= 77) return 'Karlı';
    if (code <= 82) return 'Sağanak';
    if (code <= 86) return 'Kar Sağanağı';
    if (code <= 99) return 'Fırtınalı';
    return 'Bilinmiyor';
  }

  static Future<List<LocationResult>> searchLocations(String query) async {
    if (query.length < 2) return [];
    try {
      final url = 'https://geocoding-api.open-meteo.com/v1/search?name=$query&count=10&language=tr&format=json';
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['results'] as List?;
        if (results == null) return [];
        return results.map((r) => LocationResult(
          name: r['name'] ?? '',
          lat: (r['latitude'] ?? 0.0).toDouble(),
          lng: (r['longitude'] ?? 0.0).toDouble(),
          admin1: r['admin1'] ?? '',
          country: r['country'] ?? '',
        )).toList();
      }
      return [];
    } catch (e) {
      dev.log("Search error: $e");
      return [];
    }
  }
}
