import 'dart:io';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProductImage extends StatelessWidget {
  final String? imageSource;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ProductImage({
    super.key,
    required this.imageSource,
    this.width = 90,
    this.height = 90,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);

    Widget imageWidget;

    if (imageSource == null || imageSource!.trim().isEmpty) {
      imageWidget = _buildPlaceholder();
    } else {
      final src = imageSource!.trim();
      if (src.startsWith('http://') || src.startsWith('https://')) {
        // Caché en disco: las imágenes siguen visibles sin conexión.
        imageWidget = CachedNetworkImage(
          imageUrl: src,
          width: width,
          height: height,
          fit: fit,
          placeholder: (context, url) => Container(
            width: width,
            height: height,
            color: AppTheme.softPinkBg,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.darkPink),
              ),
            ),
          ),
          errorWidget: (context, url, error) => _buildPlaceholder(),
        );
      } else if (src.startsWith('data:image') || (src.length > 100 && !src.contains('/') && !src.contains('\\'))) {
        try {
          final cleanBase64 = src.contains(',') ? src.split(',').last : src;
          final bytes = base64Decode(cleanBase64);
          imageWidget = Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
          );
        } catch (_) {
          imageWidget = _buildPlaceholder();
        }
      } else {
        // Local file path from ImagePicker
        final file = File(src);
        if (file.existsSync()) {
          imageWidget = Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
          );
        } else {
          imageWidget = _buildPlaceholder();
        }
      }
    }

    return ClipRRect(
      borderRadius: radius,
      child: imageWidget,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppTheme.softPinkBg,
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          color: AppTheme.darkPink,
          size: 32,
        ),
      ),
    );
  }
}
