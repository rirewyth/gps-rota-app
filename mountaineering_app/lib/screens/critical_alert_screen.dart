import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CriticalAlertScreen extends StatefulWidget {
  final double magnitude;
  final double secondsLeft;
  final String location;
  final double lat;
  final double lng;

  const CriticalAlertScreen({
    Key? key,
    required this.magnitude,
    required this.secondsLeft,
    required this.location,
    required this.lat,
    required this.lng,
  }) : super(key: key);

  @override
  State<CriticalAlertScreen> createState() => _CriticalAlertScreenState();
}

class _CriticalAlertScreenState extends State<CriticalAlertScreen> {
  late Timer _timer;
  late double _remainingSeconds;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmStopped = false;
  bool _showSafetyCheck = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.secondsLeft;
    _startCountdown();
    _playAlarm();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer.cancel();
        if (mounted) {
          setState(() => _showSafetyCheck = true);
        }
      }
    });
  }

  Future<void> _playAlarm() async {
    await _audioPlayer.setLoopMode(LoopMode.one);
    await _audioPlayer.setAsset('assets/audio/siren.mp3');
    _audioPlayer.play();
    
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [500, 500, 500, 500], repeat: 0);
    }
  }

  void _stopAlarm() {
    _audioPlayer.stop();
    Vibration.cancel();
    setState(() {
      _isAlarmStopped = true;
      _showSafetyCheck = true;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _audioPlayer.dispose();
    Vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0000), // Very dark red
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.red.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Header
                FadeInDown(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.redAccent, width: 2),
                        ),
                        child: const Text(
                          'KRİTİK DEPREM UYARISI',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.location.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Magnitude & Timer
                Pulse(
                  infinite: true,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.redAccent, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'M ${widget.magnitude.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Divider(color: Colors.white24, indent: 50, endIndent: 50),
                        Text(
                          _remainingSeconds > 0 
                            ? '${_remainingSeconds.toInt()} sn' 
                            : 'DALGA ULAŞTI',
                          style: TextStyle(
                            color: _remainingSeconds > 0 ? Colors.orangeAccent : Colors.redAccent,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Map Preview
                Container(
                  height: 250,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10, width: 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(widget.lat, widget.lng),
                      initialZoom: 8.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(widget.lat, widget.lng),
                            width: 80,
                            height: 80,
                            child: Pulse(
                              infinite: true,
                              child: const Icon(
                                Icons.stars,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ),
                        ],
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(widget.lat, widget.lng),
                            radius: 50000, // 50km visual hint
                            useRadiusInMeter: true,
                            color: Colors.red.withOpacity(0.2),
                            borderColor: Colors.red,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      if (_showSafetyCheck) 
                        FadeInUp(
                          child: Column(
                            children: [
                              const Text(
                                'DURUMUNUZ NEDİR?',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _updateSafetyStatus('safe'),
                                      icon: const Icon(Icons.check_circle),
                                      label: const Text('GÜVENDEYİM'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _updateSafetyStatus('assistance_needed'),
                                      icon: const Icon(Icons.warning),
                                      label: const Text('YARDIM LAZIM'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('KAPAT'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (!_isAlarmStopped)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _stopAlarm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('ALARMI DURDUR'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSafetyStatus(String status) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'safety_status': status,
      'last_safety_update': FieldValue.serverTimestamp(),
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'safe' ? 'Durumunuz "Güvende" olarak güncellendi.' : 'Yardım çağrınız ekibe iletildi!'),
          backgroundColor: status == 'safe' ? Colors.green : Colors.orange,
        ),
      );
      if (status == 'safe') {
        Navigator.pop(context);
      }
    }
  }
}
