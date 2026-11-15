import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';
import '../storage_helper.dart';
import '../services/tactical_styles.dart';

class MeshNetworkScreen extends StatefulWidget {
  const MeshNetworkScreen({Key? key}) : super(key: key);

  @override
  State<MeshNetworkScreen> createState() => _MeshNetworkScreenState();
}

class _MeshNetworkScreenState extends State<MeshNetworkScreen> {
  static const Color kOrange = TacticalStyles.kPrimaryContainer;
  static const Color kCardBg = TacticalStyles.kSurfaceLow;
  static const Color kBackground = TacticalStyles.kSurface;
  static const Color kGreen = TacticalStyles.kTertiary;

  static const String _serviceId = 'rotameshp2p';

  bool _isAdvertising = false;
  bool _isDiscovering = false;
  bool _isAutoConnectEnabled = true; // PRO Özellik: Otomatik Bağlanma
  
  final Map<String, String> _discoveredDevices = {}; // endpointId -> name
  final List<String> _connectedEndpoints = [];
  final List<_MeshMessage> _messages = [];
  String _status = 'Arama Bekleniyor';
  bool _permissionsGranted = false;
  bool _isRecording = false;
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final _sfxPlayer = AudioPlayer();
  String _myName = 'USER';
  Position? _currentPosition;
  String? _connectingToId;

  @override
  void initState() {
    super.initState();
    _loadName();
    _requestPermissionsAndInit();
  }

  Future<void> _loadName() async {
    final name = await StorageHelper.getUserName();
    if (name != null) setState(() => _myName = name);
  }

  Future<void> _requestPermissionsAndInit() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.nearbyWifiDevices,
      Permission.location,
    ].request();

    final allGranted = statuses.values.every((s) => s.isGranted || s.isLimited);
    if (mounted) setState(() => _permissionsGranted = allGranted);

    if (allGranted) {
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
        if (mounted) setState(() => _currentPosition = pos);
        // Otomatik olarak her iki modu da başlat (Mesh konsepti)
        _startAdvertising();
        _startDiscovery();
      } catch (_) {}
    }
  }

  String get _myCoordString => _currentPosition != null
      ? '${_currentPosition!.latitude.toStringAsFixed(5)},${_currentPosition!.longitude.toStringAsFixed(5)}'
      : 'KONUM_BILINMIYOR';

  Future<void> _startAdvertising() async {
    if (!_permissionsGranted) return;
    try {
      await Nearby().startAdvertising(
        'ROTA+_USER',
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: (endId, info) async {
          if (_isAutoConnectEnabled) {
            await Nearby().acceptConnection(
              endId,
              onPayLoadRecieved: (endId, payload) => _onPayloadReceived(endId, payload),
            );
          } else {
            _showConnectionRequest(endId, info.endpointName);
          }
        },
        onConnectionResult: (endId, status) {
          if (status == Status.CONNECTED) {
            setState(() {
              _connectedEndpoints.add(endId);
              _addSystemMessage('${_discoveredDevices[endId] ?? endId} bağlandı!');
            });
          }
        },
        onDisconnected: (endId) {
          setState(() {
            _connectedEndpoints.remove(endId);
            _addSystemMessage('Bağlantı koptu.');
          });
        },
        serviceId: _serviceId,
      );
      setState(() { _isAdvertising = true; _status = 'MESH AKTİF: Yayın Yapılıyor'; });
    } catch (e) { print('Adv Error: $e'); }
  }

  Future<void> _startDiscovery() async {
    if (!_permissionsGranted) return;
    try {
      await Nearby().startDiscovery(
        'ROTA+_USER',
        Strategy.P2P_CLUSTER,
        onEndpointFound: (endId, name, serviceId) {
          setState(() {
            _discoveredDevices[endId] = name;
            _addSystemMessage('Düğüm bulundu: $name');
          });
          // PRO: Otomatik olarak bulunanlara bağlanma isteği gönder
          if (_isAutoConnectEnabled && !_connectedEndpoints.contains(endId)) {
            _connectTo(endId);
          }
        },
        onEndpointLost: (endId) {
          setState(() => _discoveredDevices.remove(endId));
        },
        serviceId: _serviceId,
      );
      setState(() { _isDiscovering = true; _status = 'MESH AKTİF: Çevre Taranıyor'; });
    } catch (e) { print('Disc Error: $e'); }
  }

  void _showConnectionRequest(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('BAĞLANTI İSTEĞİ', style: TextStyle(color: kOrange)),
        content: Text('$name sizinle eşleşmek istiyor.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('REDDET', style: TextStyle(color: Colors.redAccent))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () async {
              Navigator.pop(ctx);
              await Nearby().acceptConnection(id, onPayLoadRecieved: (id, p) => _onPayloadReceived(id, p));
            },
            child: const Text('KABUL ET', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _connectTo(String endId) async {
    if (_connectedEndpoints.contains(endId)) return;
    try {
      await Nearby().requestConnection(
        'ROTA+_USER',
        endId,
        onConnectionInitiated: (endId, info) async {
          await Nearby().acceptConnection(endId, onPayLoadRecieved: (endId, p) => _onPayloadReceived(endId, p));
        },
        onConnectionResult: (endId, status) {
          if (status == Status.CONNECTED) {
            setState(() {
              _connectedEndpoints.add(endId);
              _addSystemMessage('Bağlantı başarılı: $endId');
            });
          }
        },
        onDisconnected: (endId) {
          setState(() => _connectedEndpoints.remove(endId));
        },
      );
    } catch (e) { print('Connect Error: $e'); }
  }

  void _onPayloadReceived(String endId, Payload payload) {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      final String raw = String.fromCharCodes(payload.bytes!);
      
      // Check if it's a JSON payload (for Voice or Metadata)
      try {
        final Map<String, dynamic> data = jsonDecode(raw);
        if (data['type'] == 'voice') {
           _handleVoicePayload(endId, data);
           return;
        }
      } catch (_) {
        // Not JSON, treat as plain text message
      }

      final msg = raw;
      setState(() {
        _messages.insert(0, _MeshMessage(
          msgId: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: _discoveredDevices[endId] ?? 'Bilinmeyen Düğüm',
          text: msg,
          isMe: false,
          time: DateTime.now(),
        ));
      });
    }
  }

  Future<void> _handleVoicePayload(String endId, Map<String, dynamic> data) async {
    final String sender = data['sender'] ?? 'Bilinmeyen';
    final String audioBase64 = data['audio'];
    final String msgId = data['msgId'];

    // Check if we already received/relayed this message to prevent loops
    if (_messages.any((m) => m.msgId == msgId)) return;

    setState(() {
      _messages.insert(0, _MeshMessage(
        msgId: msgId,
        sender: sender,
        text: '[SESLİ MESAJ]',
        isMe: false,
        isVoice: true,
        time: DateTime.now(),
      ));
    });

    // Play the audio
    try {
      final bytes = base64Decode(audioBase64);
      final dir = await getTemporaryDirectory();
      final tmpFile = File('${dir.path}/mesh_voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await tmpFile.writeAsBytes(bytes);
      await _audioPlayer.setFilePath(tmpFile.path);
      _audioPlayer.play();
    } catch (e) {
      print('Voice play error: $e');
    }

    // RELAY: Send to all OTHER connected endpoints (Hopping)
    final relayPayload = Uint8List.fromList(jsonEncode(data).codeUnits);
    for (final otherEndId in _connectedEndpoints) {
      if (otherEndId != endId) {
        Nearby().sendBytesPayload(otherEndId, relayPayload);
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;
    final msgId = DateTime.now().millisecondsSinceEpoch.toString();
    final bytes = Uint8List.fromList(text.codeUnits);
    for (final endId in _connectedEndpoints) {
      await Nearby().sendBytesPayload(endId, bytes);
    }
    setState(() {
      _messages.insert(0, _MeshMessage(msgId: msgId, sender: 'SİZ', text: text, isMe: true, time: DateTime.now()));
    });
  }

  Future<void> _sendVoiceMessage(String path) async {
    final file = File(path);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    final audioBase64 = base64Encode(bytes);
    final msgId = 'v_${DateTime.now().millisecondsSinceEpoch}';

    final Map<String, dynamic> data = {
      'type': 'voice',
      'msgId': msgId,
      'sender': _myName,
      'audio': audioBase64,
    };

    final payload = Uint8List.fromList(jsonEncode(data).codeUnits);
    for (final endId in _connectedEndpoints) {
      await Nearby().sendBytesPayload(endId, payload);
    }

    setState(() {
      _messages.insert(0, _MeshMessage(
        msgId: msgId,
        sender: 'SİZ',
        text: '[SESLİ MESAJ GÖNDERİLDİ]',
        isMe: true,
        isVoice: true,
        time: DateTime.now(),
      ));
    });
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.insert(0, _MeshMessage(
        msgId: 'sys_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'SİSTEM',
        text: text,
        isMe: false,
        isSystem: true,
        time: DateTime.now(),
      ));
    });
  }

  @override
  void dispose() {
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        centerTitle: true,
        title: TacticalStyles.appBarPill('DOĞA MESH AĞI', icon: Icons.hub_outlined),
        actions: [
          IconButton(
            icon: Icon(_isAutoConnectEnabled ? Icons.auto_fix_high : Icons.auto_fix_off, color: _isAutoConnectEnabled ? kGreen : TacticalStyles.kOnSurfaceVariant),
            onPressed: () => setState(() => _isAutoConnectEnabled = !_isAutoConnectEnabled),
            tooltip: 'Otomatik Bağlanma',
          ),
        ],
      ),
      body: Column(
        children: [
          // Transport Status Header
          _buildTransportHeader(),
          
          // Mesh Grid Animation View
          Container(
            height: 120,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: TacticalStyles.glassCardDecoration(radius: 16),
            child: Stack(
              children: [
                Center(child: Icon(Icons.hub, color: kOrange.withOpacity(0.1), size: 80)),
                Positioned.fill(child: _buildMeshDots()),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${_connectedEndpoints.length}', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kGreen, fontSize: 32, fontWeight: FontWeight.bold)),
                      Text('AKTİF DÜĞÜM', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kGreen.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Discovered Node List
          if (_discoveredDevices.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.radar, color: TacticalStyles.kSecondaryContainer, size: 14),
                  const SizedBox(width: 8),
                  Text('KEŞFEDİLEN DÜĞÜMLER', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kSecondaryContainer, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _discoveredDevices.entries.map((e) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _connectedEndpoints.contains(e.key) ? kGreen.withOpacity(0.12) : kCardBg,
                    border: Border.all(color: _connectedEndpoints.contains(e.key) ? kGreen : TacticalStyles.kOutlineVariant),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(child: Text(e.value, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurface, fontSize: 11, fontWeight: FontWeight.w600))),
                )).toList(),
              ),
            ),
          ],

          // Messages
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: TacticalStyles.kOutlineVariant)),
              child: ListView.builder(
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
              ),
            ),
          ),

          // Input
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildTransportHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _transportBadge('WiFi Direct', _isAdvertising || _isDiscovering),
          const SizedBox(width: 8),
          _transportBadge('Bluetooth 5.0', _isAdvertising || _isDiscovering),
          const Spacer(),
          Text(_status, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _transportBadge(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? kGreen.withOpacity(0.1) : TacticalStyles.kSurfaceLow,
        border: Border.all(color: active ? kGreen : TacticalStyles.kOutlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? kGreen : TacticalStyles.kOnSurfaceVariant)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: active ? kGreen : TacticalStyles.kOnSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMeshDots() {
    return const Center(child: Opacity(opacity: 0.2, child: Icon(Icons.blur_on, color: kOrange, size: 100)));
  }

  Widget _buildMessageBubble(_MeshMessage m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: m.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!m.isMe) Text(m.sender, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: m.isSystem ? TacticalStyles.kOnSurfaceVariant : kOrange, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('${m.time.hour}:${m.time.minute}', style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 8)),
              if (m.isMe) const SizedBox(width: 8),
              if (m.isMe) Text('SİZ', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kGreen, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: m.isSystem ? Colors.transparent : m.isMe ? kGreen.withOpacity(0.1) : TacticalStyles.kSurfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: m.isSystem ? TacticalStyles.kOutlineVariant : m.isMe ? kGreen.withOpacity(0.3) : TacticalStyles.kOutlineVariant),
            ),
            child: Text(m.isVoice ? '▶ SESLİ MESAJI DİNLE' : m.text, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: m.isSystem ? TacticalStyles.kOnSurfaceVariant : (m.isVoice ? kOrange : TacticalStyles.kOnSurface), fontSize: 13, fontWeight: m.isVoice ? FontWeight.bold : FontWeight.normal)),
          ),
          if (m.isVoice)
             const Padding(
               padding: EdgeInsets.only(top: 4, left: 4),
               child: Text('Dokunarak tekrar dinle', style: TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 8)),
             ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final TextEditingController ctrl = TextEditingController();
    return Container(
      padding: const EdgeInsets.all(16),
      color: TacticalStyles.kSurfaceLowest,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(color: TacticalStyles.kOnSurface),
              decoration: InputDecoration(
                hintText: 'Mesaj gönder...',
                hintStyle: const TextStyle(color: TacticalStyles.kOnSurfaceVariant),
                filled: true,
                fillColor: kCardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TacticalStyles.kOutlineVariant)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TacticalStyles.kOutlineVariant)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onLongPressStart: (_) async {
              if (await _audioRecorder.hasPermission()) {
                Vibration.vibrate(duration: 50);
                final dir = await getTemporaryDirectory();
                final path = '${dir.path}/mesh_v_${DateTime.now().millisecondsSinceEpoch}.m4a';
                await _audioRecorder.start(const RecordConfig(), path: path);
                setState(() => _isRecording = true);
              }
            },
            onLongPressEnd: (_) async {
              final path = await _audioRecorder.stop();
              setState(() => _isRecording = false);
              if (path != null) _sendVoiceMessage(path);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isRecording ? TacticalStyles.kErrorContainer : kCardBg,
                shape: BoxShape.circle,
                border: Border.all(color: _isRecording ? TacticalStyles.kError : TacticalStyles.kOutlineVariant),
              ),
              child: Icon(Icons.mic, color: _isRecording ? Colors.white : kOrange, size: 24),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: kOrange),
            onPressed: () {
              _sendMessage(ctrl.text);
              ctrl.clear();
            },
          ),
        ],
      ),
    );
  }
}

class _MeshMessage {
  final String msgId;
  final String sender;
  final String text;
  final bool isMe;
  final bool isSystem;
  final bool isVoice;
  final DateTime time;

  _MeshMessage({
    required this.msgId,
    required this.sender, 
    required this.text, 
    required this.isMe, 
    this.isSystem = false, 
    this.isVoice = false,
    required this.time
  });
}
