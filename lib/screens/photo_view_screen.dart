import 'dart:io';
import 'package:flutter/material.dart';
import '../models/photo_status_model.dart';
import '../services/api_service.dart';

class PhotoViewScreen extends StatelessWidget {
  final PhotoDisplay photo;
  final String? authToken;

  const PhotoViewScreen({super.key, required this.photo, this.authToken});

  @override
  Widget build(BuildContext context) {
    Widget image;
    // CORRECCIÓN: Se construye la URL correcta para las fotos subidas.
    if (photo.status == PhotoStatusType.uploaded && photo.remoteId != null) {
      final secureUrl = '${ApiService.baseUrl}/v1/private-fotos/${photo.remoteId}';
      image = Image.network(
        secureUrl,
        headers: {'Authorization': 'Bearer $authToken'},
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    } else {
      image = Image.file(File(photo.path));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 1.0,
          maxScale: 4.0,
          child: image,
        ),
      ),
    );
  }
}

