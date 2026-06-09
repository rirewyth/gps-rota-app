import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'services/cloud_sync_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static final ValueNotifier<int> rotaUpdateNotifier = ValueNotifier(0);
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('rota_plus.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE konum_gecmisi (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  enlem REAL NOT NULL,
  boylam REAL NOT NULL,
  yukseklik REAL NOT NULL,
  zaman TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE mesajlar (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  metin TEXT NOT NULL,
  benden INTEGER NOT NULL,
  saat TEXT NOT NULL,
  tip TEXT DEFAULT 'SMS',
  is_sos INTEGER DEFAULT 0
)
''');
    await db.execute('''
CREATE TABLE rotalar (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  isim TEXT NOT NULL,
  noktalar TEXT NOT NULL,
  olusturma_tarihi TEXT NOT NULL,
  aktif INTEGER DEFAULT 0,
  baslangic_adi TEXT DEFAULT '',
  bitis_adi TEXT DEFAULT '',
  distance REAL DEFAULT 0,
  duration_seconds INTEGER DEFAULT 0,
  elevation_gain REAL DEFAULT 0,
  max_altitude REAL DEFAULT 0,
  steps INTEGER DEFAULT 0,
  source TEXT DEFAULT ''
)
''');
    await db.execute('''
CREATE TABLE kullanicilar (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ad TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  sifre_hash TEXT NOT NULL,
  kan_grubu TEXT DEFAULT '',
  tibbi_bilgi TEXT DEFAULT '',
  acil_kisi TEXT DEFAULT '',
  acil_tel TEXT DEFAULT '',
  kayit_tarihi TEXT NOT NULL,
  is_admin INTEGER DEFAULT 0,
  is_premium INTEGER DEFAULT 0,
  toplam_tirnani INTEGER DEFAULT 0,
  max_irtifa REAL DEFAULT 0
)
''');
    // Varsayilan admin kullanicisi
    await db.insert('kullanicilar', {
      'ad': 'SİSTEM ADMİNİ',
      'email': 'admin@rota.plus',
      'sifre_hash': _hashPassword('admin2024'),
      'kayit_tarihi': DateTime.now().toIso8601String(),
      'is_admin': 1,
      'is_premium': 1,
    });
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE mesajlar ADD COLUMN tip TEXT DEFAULT "SMS"');
        await db.execute('ALTER TABLE mesajlar ADD COLUMN is_sos INTEGER DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
CREATE TABLE IF NOT EXISTS kullanicilar (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ad TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  sifre_hash TEXT NOT NULL,
  kan_grubu TEXT DEFAULT '',
  tibbi_bilgi TEXT DEFAULT '',
  acil_kisi TEXT DEFAULT '',
  acil_tel TEXT DEFAULT '',
  kayit_tarihi TEXT NOT NULL,
  is_admin INTEGER DEFAULT 0,
  is_premium INTEGER DEFAULT 0,
  toplam_tirnani INTEGER DEFAULT 0,
  max_irtifa REAL DEFAULT 0
)
''');
        // Admin ekle
        try {
          await db.insert('kullanicilar', {
            'ad': 'SİSTEM ADMİNİ',
            'email': 'admin@rota.plus',
            'sifre_hash': _hashPassword('admin2024'),
            'kayit_tarihi': DateTime.now().toIso8601String(),
            'is_admin': 1,
            'is_premium': 1,
          });
        } catch (_) {}

        // rotalar tablosuna yeni kolonlar ekle
        try {
          await db.execute('ALTER TABLE rotalar ADD COLUMN baslangic_adi TEXT DEFAULT ""');
          await db.execute('ALTER TABLE rotalar ADD COLUMN bitis_adi TEXT DEFAULT ""');
        } catch (_) {}
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE rotalar ADD COLUMN distance REAL DEFAULT 0');
        await db.execute('ALTER TABLE rotalar ADD COLUMN duration_seconds INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE rotalar ADD COLUMN elevation_gain REAL DEFAULT 0');
        await db.execute('ALTER TABLE rotalar ADD COLUMN max_altitude REAL DEFAULT 0');
        await db.execute('ALTER TABLE rotalar ADD COLUMN steps INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE rotalar ADD COLUMN source TEXT DEFAULT ""');
      } catch (_) {}
    }
  }

  // SHA-256 sifre hash
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ─── KULLANICI AUTH ────────────────────────────────────────────

  /// Yeni kullanici kaydeder. Doner: id >= 1 basarili, -2 email var, -1 hata
  Future<int> kullaniciKaydet({
    required String ad,
    required String email,
    required String sifre,
  }) async {
    try {
      final db = await instance.database;
      final mevcut = await db.query('kullanicilar',
          where: 'email = ?', whereArgs: [email.toLowerCase().trim()]);
      if (mevcut.isNotEmpty) return -2;
      return await db.insert('kullanicilar', {
        'ad': ad.trim(),
        'email': email.toLowerCase().trim(),
        'sifre_hash': _hashPassword(sifre),
        'kayit_tarihi': DateTime.now().toIso8601String(),
        'is_admin': 0,
        'is_premium': 0,
      });
    } catch (_) {
      return -1;
    }
  }

  /// Giris dogrula. Basarirsa kullanici verisini doner
  Future<Map<String, dynamic>?> kullaniciGirisDogrula(
      String email, String sifre) async {
    try {
      final db = await instance.database;
      final rows = await db.query(
        'kullanicilar',
        where: 'email = ? AND sifre_hash = ?',
        whereArgs: [email.toLowerCase().trim(), _hashPassword(sifre)],
      );
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (_) {
      return null;
    }
  }

  /// Kullanici emailine gore bul
  Future<Map<String, dynamic>?> kullaniciBul(String email) async {
    try {
      final db = await instance.database;
      final rows = await db.query('kullanicilar',
          where: 'email = ?', whereArgs: [email.toLowerCase().trim()]);
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (_) {
      return null;
    }
  }

  /// Tum kullanicilari listele (Admin icin)
  Future<List<Map<String, dynamic>>> tumKullanicilariGetir() async {
    try {
      final db = await instance.database;
      final rows = await db.query('kullanicilar', orderBy: 'id DESC');
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Kullanici sayisi
  Future<int> kullaniciSayisi() async {
    try {
      final db = await instance.database;
      final result =
          await db.rawQuery('SELECT COUNT(*) as count FROM kullanicilar');
      return (result.first['count'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Premium kullanici sayisi
  Future<int> premiumKullaniciSayisi() async {
    try {
      final db = await instance.database;
      final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM kullanicilar WHERE is_premium = 1');
      return (result.first['count'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Kullanici guncelle
  Future<void> kullaniciGuncelle(int id, Map<String, dynamic> data) async {
    try {
      final db = await instance.database;
      await db.update('kullanicilar', data,
          where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  /// Kullanici premium yap
  Future<void> kullaniciPremiumYap(int id, bool premium) async {
    try {
      final db = await instance.database;
      await db.update('kullanicilar', {'is_premium': premium ? 1 : 0},
          where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  /// Kullanici sil
  Future<void> kullaniciSil(int id) async {
    try {
      final db = await instance.database;
      await db.delete('kullanicilar', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  /// Kullanici sifresi degistir (Admin icin)
  Future<void> kullaniciSifreDegistir(int id, String yeniSifre) async {
    try {
      final db = await instance.database;
      await db.update(
        'kullanicilar',
        {'sifre_hash': _hashPassword(yeniSifre)},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (_) {}
  }

  // ─── KONUM ─────────────────────────────────────────────────────
  Future<void> insertLocation(
      double lat, double lng, double alt, String timestamp) async {
    try {
      final db = await instance.database;
      await db.insert('konum_gecmisi', {
        'enlem': lat,
        'boylam': lng,
        'yukseklik': alt,
        'zaman': timestamp
      });
      CloudSyncService.syncLocation(lat, lng, alt, timestamp);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getLastLocations(int count) async {
    try {
      final db = await instance.database;
      final result = await db.query('konum_gecmisi',
          orderBy: 'zaman DESC', limit: count);
      return result.map((row) => {
        'latitude': row['enlem'] ?? 0.0,
        'longitude': row['boylam'] ?? 0.0,
        'altitude': row['yukseklik'] ?? 0.0,
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── MESAJ ─────────────────────────────────────────────────────
  Future<void> mesajKaydet(String metin, String tip,
      {int isSos = 0, bool benden = true}) async {
    try {
      final db = await instance.database;
      await db.insert('mesajlar', {
        'metin': metin,
        'benden': benden ? 1 : 0,
        'saat': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        'tip': tip,
        'is_sos': isSos
      });
      CloudSyncService.syncMessage(metin, tip, isSos == 1);
    } catch (_) {}
  }

  Future<void> insertMessage(String text, bool isMe, String time) async {
    await mesajKaydet(text, 'SMS', isSos: 0, benden: isMe);
  }

  Future<List<Map<String, dynamic>>> getAllMessages() async {
    try {
      final db = await instance.database;
      final result =
          await db.query('mesajlar', orderBy: 'id DESC');
      return result.map((json) => {
        'id': json['id'],
        'content': json['metin'] ?? '',
        'text': json['metin'] ?? '',
        'isMe': (json['benden'] ?? 0) == 1,
        'time': json['saat'] ?? '',
        'type': json['tip'] ?? 'SMS',
        'is_sos': json['is_sos'] ?? 0,
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── ROTA ──────────────────────────────────────────────────────

  /// Rota kaydeder. noktalar: [{"lat":40.1,"lng":29.2}, ...]
  Future<int> rotaKaydet(
    String isim,
    List<Map<String, double>> noktalar, {
    String baslangicAdi = '',
    String bitisAdi = '',
    double distance = 0,
    int durationSeconds = 0,
    double elevationGain = 0,
    double maxAltitude = 0,
    int steps = 0,
    String source = '',
  }) async {
    final db = await instance.database;
    // Bulut senkronizasyonu
    CloudSyncService.syncRoute(
      isim,
      noktalar,
      baslangicAdi,
      bitisAdi,
      distance: distance,
      durationSeconds: durationSeconds,
      elevationGain: elevationGain,
      maxAltitude: maxAltitude,
      steps: steps,
      source: source,
    );
    final id = await db.insert('rotalar', {
      'isim': isim,
      'noktalar': jsonEncode(noktalar),
      'olusturma_tarihi': DateTime.now().toIso8601String(),
      'aktif': 0,
      'baslangic_adi': baslangicAdi,
      'bitis_adi': bitisAdi,
      'distance': distance,
      'duration_seconds': durationSeconds,
      'elevation_gain': elevationGain,
      'max_altitude': maxAltitude,
      'steps': steps,
      'source': source,
    });
    rotaUpdateNotifier.value++;
    return id;
  }

  /// Aktif rotayi getirir
  Future<Map<String, dynamic>?> aktifRotaGetir() async {
    try {
      final db = await instance.database;
      final rows =
          await db.query('rotalar', where: 'aktif = 1', limit: 1);
      if (rows.isEmpty) return null;
      final row = rows.first;
      final noktalarJson =
          jsonDecode(row['noktalar'] as String) as List;
      return {
        'id': row['id'],
        'isim': row['isim'],
        'noktalar': noktalarJson,
        'tarih': row['olusturma_tarihi'],
        'baslangic_adi': row['baslangic_adi'] ?? '',
        'bitis_adi': row['bitis_adi'] ?? '',
        'distance': (row['distance'] as num?)?.toDouble() ?? 0.0,
        'duration_seconds': (row['duration_seconds'] as num?)?.toInt() ?? 0,
        'elevation_gain': (row['elevation_gain'] as num?)?.toDouble() ?? 0.0,
        'max_altitude': (row['max_altitude'] as num?)?.toDouble() ?? 0.0,
        'steps': (row['steps'] as num?)?.toInt() ?? 0,
        'source': row['source'] ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  /// Belirli bir rotayi getirir
  Future<Map<String, dynamic>?> rotaGetir(int id) async {
    try {
      final db = await instance.database;
      final rows = await db.query('rotalar', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return null;
      final row = rows.first;
      final List noktalar = jsonDecode(row['noktalar'] as String);
      return {
        'id': row['id'],
        'isim': row['isim'],
        'noktalar': noktalar,
        'tarih': row['olusturma_tarihi'],
        'aktif': (row['aktif'] as int) == 1,
        'baslangic_adi': row['baslangic_adi'] ?? '',
        'bitis_adi': row['bitis_adi'] ?? '',
        'distance': (row['distance'] as num?)?.toDouble() ?? 0.0,
        'duration_seconds': (row['duration_seconds'] as num?)?.toInt() ?? 0,
        'elevation_gain': (row['elevation_gain'] as num?)?.toDouble() ?? 0.0,
        'max_altitude': (row['max_altitude'] as num?)?.toDouble() ?? 0.0,
        'steps': (row['steps'] as num?)?.toInt() ?? 0,
        'source': row['source'] ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  /// Tum rotaları listeler
  Future<List<Map<String, dynamic>>> tumRotalarGetir() async {
    try {
      final db = await instance.database;
      final rows = await db.query('rotalar', orderBy: 'id DESC');
      return rows.map((row) {
        final List noktalar =
            jsonDecode(row['noktalar'] as String);
        return {
          'id': row['id'],
          'isim': row['isim'],
          'noktalarSayisi': noktalar.length,
          'noktalar': noktalar,
          'tarih': row['olusturma_tarihi'],
          'aktif': (row['aktif'] as int) == 1,
          'baslangic_adi': row['baslangic_adi'] ?? '',
          'bitis_adi': row['bitis_adi'] ?? '',
          'distance': (row['distance'] as num?)?.toDouble() ?? 0.0,
          'duration_seconds': (row['duration_seconds'] as num?)?.toInt() ?? 0,
          'elevation_gain': (row['elevation_gain'] as num?)?.toDouble() ?? 0.0,
          'max_altitude': (row['max_altitude'] as num?)?.toDouble() ?? 0.0,
          'steps': (row['steps'] as num?)?.toInt() ?? 0,
          'source': row['source'] ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Rota sayisi
  Future<int> rotaSayisi() async {
    try {
      final db = await instance.database;
      final result =
          await db.rawQuery('SELECT COUNT(*) as count FROM rotalar');
      return (result.first['count'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Rotayi aktif yap
  Future<void> rotayiAktifYap(int id) async {
    final db = await instance.database;
    await db.update('rotalar', {'aktif': 0});
    await db.update('rotalar', {'aktif': 1},
        where: 'id = ?', whereArgs: [id]);
    rotaUpdateNotifier.value++;
  }

  /// Aktif rotayi temizle
  Future<void> rotayiTemizle() async {
    final db = await instance.database;
    await db.update('rotalar', {'aktif': 0});
    rotaUpdateNotifier.value++;
  }

  /// Rotayi sil
  Future<void> rotaSil(int id) async {
    final db = await instance.database;
    await db.delete('rotalar', where: 'id = ?', whereArgs: [id]);
    rotaUpdateNotifier.value++;
  }

  /// Verilen konuma en yakin rota noktasini bulur
  static Map<String, dynamic>? enYakinRotaNoktasi(
    double enlmem,
    double boylam,
    List noktalar,
  ) {
    if (noktalar.isEmpty) return null;
    int enYakinIndex = 0;
    double enKucukMesafe = double.infinity;

    for (int i = 0; i < noktalar.length; i++) {
      final n = noktalar[i];
      final dLat = (n['lat'] as num).toDouble() - enlmem;
      final dLng = (n['lng'] as num).toDouble() - boylam;
      final mesafe = sqrt(dLat * dLat + dLng * dLng);
      if (mesafe < enKucukMesafe) {
        enKucukMesafe = mesafe;
        enYakinIndex = i;
      }
    }
    return {
      'index': enYakinIndex,
      'toplam': noktalar.length,
      'lat': (noktalar[enYakinIndex]['lat'] as num).toDouble(),
      'lng': (noktalar[enYakinIndex]['lng'] as num).toDouble(),
    };
  }
}
