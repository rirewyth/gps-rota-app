import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mountaineering_app/services/earthquake_service.dart';

class EarthquakeFeedScreen extends StatefulWidget {
  const EarthquakeFeedScreen({Key? key}) : super(key: key);

  @override
  State<EarthquakeFeedScreen> createState() => _EarthquakeFeedScreenState();
}

class _EarthquakeFeedScreenState extends State<EarthquakeFeedScreen> {
  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kBackground = Color(0xFF0A0A0A);
  static const Color kCardBg = Color(0xFF141414);

  final EarthquakeService _quakeService = EarthquakeService();
  List<EarthquakeModel> _quakes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final kandilli = await _quakeService.getRecentEarthquakes();
      final aprs = await _quakeService.getAprsTacticalFeed();
      if (mounted) {
        setState(() {
          _quakes = [...aprs, ...kandilli];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('DEPREM TAKİBİ', style: GoogleFonts.shareTechMono(color: kOrange, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: kOrange))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _quakes.length,
            itemBuilder: (context, index) {
              final q = _quakes[index];
              final isSignificant = q.mag >= 4.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSignificant ? Colors.redAccent.withOpacity(0.5) : Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: isSignificant ? Colors.redAccent : kOrange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(q.mag.toString(), style: GoogleFonts.shareTechMono(color: isSignificant ? Colors.white : kOrange, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.location, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('${q.date} | Derinlik: ${q.depth}km', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
}
