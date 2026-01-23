import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class CustomBanner extends StatefulWidget {
  const CustomBanner({
    super.key,
    required this.title,
    required this.onTap,
    this.storagePath = 'banner/dambell/character_noukin.png',
  });

  final String title;
  final VoidCallback onTap;
  final String storagePath;

  @override
  State<CustomBanner> createState() => _CustomBannerState();
}

class _CustomBannerState extends State<CustomBanner> {
  late final Future<String?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _loadImageUrl();
  }

  Future<String?> _loadImageUrl() async {
    try {
      return await FirebaseStorage.instance
          .ref()
          .child(widget.storagePath)
          .getDownloadURL();
    } catch (e) {
      debugPrint('CustomBanner: failed to load URL for ${widget.storagePath}: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(15.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.0),
          child: Row(
            children: [
              Container(
                width: 100,
                height: double.infinity,
                color: const Color(0xFFFFAB4C),
                child: FutureBuilder<String?>(
                  future: _imageFuture,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      debugPrint(
                          'CustomBanner: future error for ${widget.storagePath}: ${snap.error}');
                    }
                    final url = snap.data;
                    if (url == null || url.isEmpty) {
                      return const Icon(Icons.image, color: Colors.white);
                    }
                    return Image.network(
                      url,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('CustomBanner: image load failed: $error');
                        return const Icon(Icons.image, color: Colors.white);
                      },
                    );
                  },
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
