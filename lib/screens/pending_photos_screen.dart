import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/photo_status_model.dart';
import '../services/database_service.dart';
import '../services/upload_service.dart';
import '../widgets/app_background.dart';

class PendingPhotosScreen extends StatefulWidget {
  const PendingPhotosScreen({super.key});

  @override
  State<PendingPhotosScreen> createState() => _PendingPhotosScreenState();
}

class _PendingPhotosScreenState extends State<PendingPhotosScreen> {
  List<Map<String, dynamic>> _pendingPhotos = [];
  bool _isLoading = true;
  StreamSubscription<PhotoDisplay>? _uploadStatusSubscription;
  final Map<int, PhotoStatusType> _uploadingStatuses = {};
  final Map<int, String> _uploadErrors = {};

  @override
  void initState() {
    super.initState();
    _loadPendingPhotos();
    _subscribeToUploadStatus();
  }

  @override
  void dispose() {
    _uploadStatusSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToUploadStatus() {
    _uploadStatusSubscription =
        UploadService.instance.uploadStatusStream.listen((photoDisplay) {
      if (photoDisplay.localId != null) {
        if (mounted) {
          setState(() {
            if (photoDisplay.status == PhotoStatusType.uploaded) {
              _pendingPhotos
                  .removeWhere((p) => p['id'] == photoDisplay.localId);
              _uploadingStatuses.remove(photoDisplay.localId);
              _uploadErrors.remove(photoDisplay.localId);
              
              if (_pendingPhotos.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Todas las fotos se han subido correctamente.')),
                );
              }

            } else {
              _uploadingStatuses[photoDisplay.localId!] = photoDisplay.status;
              if (photoDisplay.errorMessage != null) {
                _uploadErrors[photoDisplay.localId!] =
                    photoDisplay.errorMessage!;
              }
            }
          });
        }
      }
    });
  }

  Future<void> _loadPendingPhotos() async {
    setState(() => _isLoading = true);
    try {
      final photos = await DatabaseService.instance.getPendingPhotos();
      if (mounted) {
        setState(() {
          _pendingPhotos = List.from(photos); // Make it mutable
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando fotos pendientes: $e')),
        );
      }
    }
  }

  Future<void> _syncNow() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Iniciando sincronización de fotos...')),
    );
    await UploadService.instance.syncPendingUploads();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Fotos Pendientes',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (_pendingPhotos.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.sync, color: Colors.blue),
                onPressed: _syncNow,
                tooltip: 'Sincronizar ahora',
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _pendingPhotos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 80, color: Colors.green.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No hay fotos pendientes',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingPhotos.length,
                    itemBuilder: (context, index) {
                      final photo = _pendingPhotos[index];
                      final id = photo['id'] as int;
                      final path = photo['image_path'] as String;
                      final orderNumber = photo['order_number'] as String;
                      final lastError = photo['last_error'] as String?;
                      
                      // Check real-time status, fallback to DB status if not active
                      final currentStatus = _uploadingStatuses[id] ?? 
                          (photo['sync_status'] == 'uploading' 
                              ? PhotoStatusType.uploading 
                              : PhotoStatusType.local);
                              
                      final currentError = _uploadErrors[id] ?? lastError;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: Image.file(
                                File(path),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.grey),
                                  );
                                },
                              ),
                            ),
                          ),
                          title: Text(
                            'Orden #$orderNumber',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(path.split('/').last,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              if (currentError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    currentError,
                                    style: GoogleFonts.poppins(
                                        color: Colors.red, fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                          trailing: _buildStatusIndicator(currentStatus),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildStatusIndicator(PhotoStatusType status) {
    switch (status) {
      case PhotoStatusType.uploading:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case PhotoStatusType.error:
        return const Icon(Icons.error_outline, color: Colors.red);
      case PhotoStatusType.uploaded:
        return const Icon(Icons.check_circle, color: Colors.green);
      case PhotoStatusType.local:
      default:
        return const Icon(Icons.cloud_upload_outlined, color: Colors.grey);
    }
  }
}
