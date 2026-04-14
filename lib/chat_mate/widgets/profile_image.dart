import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../api/apis.dart';
 
class ProfileImage extends StatelessWidget {
  final double size;
  final String? url;

  const ProfileImage({super.key, required this.size, this.url});

  /// Validates if the URL is actually usable for image loading
  bool _isValidUrl(String? url) {
    // Check for null, empty, or literal strings like "null"
    if (url == null || url.trim().isEmpty) {
      return false;
    }
    
    final trimmed = url.trim();
    
    // Check for common invalid string values
    if (trimmed.toLowerCase() == 'null' || 
        trimmed.toLowerCase() == 'undefined' ||
        trimmed == 'N/A') {
      return false;
    }
    
    // Verify it's a proper HTTP/HTTPS URL
    try {
      final uri = Uri.parse(trimmed);
      return uri.hasScheme && 
             uri.host.isNotEmpty && 
             (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which URL to use
    String? imageUrl = url;
    
    // If no URL provided, try to get from APIs.user.photoURL
    if (imageUrl == null || !_isValidUrl(imageUrl)) {
      final fallbackUrl = APIs.user.photoURL?.toString();
      imageUrl = _isValidUrl(fallbackUrl) ? fallbackUrl : null;
    }

    return ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(size)),
      child: imageUrl != null
          ? CachedNetworkImage(
              width: size,
              height: size,
              fit: BoxFit.cover,
              imageUrl: imageUrl,
              placeholder: (context, url) => _buildLoadingPlaceholder(),
              errorWidget: (context, url, error) => _buildAvatarPlaceholder(),
            )
          : _buildAvatarPlaceholder(),
    );
  }

  /// Loading state while image is being fetched
  Widget _buildLoadingPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size),
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.4,
          height: size * 0.4,
          child: const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }

  /// Fallback avatar when no image is available or on error
  Widget _buildAvatarPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size),
      ),
      child: Icon(
        CupertinoIcons.person,
        color: Colors.white.withOpacity(0.9),
        size: size * 0.6,
      ),
    );
  }
}