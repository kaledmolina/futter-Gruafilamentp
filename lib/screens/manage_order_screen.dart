import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/orden_model.dart';
import '../models/photo_status_model.dart';
import '../repositories/order_repository.dart';
import '../repositories/photo_repository.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/upload_service.dart';
import '../widgets/connection_status_indicator.dart';
import '../widgets/app_background.dart';
import 'photo_view_screen.dart';

class ManageOrderScreen extends StatefulWidget {
  final Orden orden;
  const ManageOrderScreen({super.key, required this.orden});

  @override
  _ManageOrderScreenState createState() => _ManageOrderScreenState();
}

class _ManageOrderScreenState extends State<ManageOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _celularController;
  late TextEditingController _obsOrigenController;
  late TextEditingController _obsDestinoController;
  
  List<PhotoDisplay> _galleryPhotos = [];
  bool _isLoading = false;
  StreamSubscription? _uploadSubscription;
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _celularController = TextEditingController(text: widget.orden.celular);
    _obsOrigenController = TextEditingController(text: widget.orden.observacionesOrigen);
    _obsDestinoController = TextEditingController(text: widget.orden.observacionesDestino);
    _initialize();
  }
  
  Future<void> _initialize() async {
    _authToken = await AuthService.instance.getToken();
    await _loadPhotos();
    
    _uploadSubscription = UploadService.instance.uploadStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          final index = _galleryPhotos.indexWhere((p) => p.localId == status.localId);
          if (index != -1) {
            if (status.status == PhotoStatusType.uploaded) {
              _loadPhotos();
            } else {
              _galleryPhotos[index] = status;
            }
          }
        });
      }
    });
  }
  
  @override
  void dispose() {
    _uploadSubscription?.cancel();
    super.dispose();
  }

  final PhotoRepository _photoRepo = PhotoRepository();

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    try {
      final photos = await _photoRepo.getPhotos(widget.orden.numeroOrden);
      if (mounted) {
        setState(() {
          _galleryPhotos = photos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar fotos: $e')),
          );
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final int currentCount = _galleryPhotos.length;
    if (currentCount >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya has alcanzado el límite de 12 fotos.')),
      );
      return;
    }

    final picker = ImagePicker();
    // Usa pickMultiImage para seleccionar varias fotos a la vez
    final pickedFiles = await picker.pickMultiImage(imageQuality: 80);

    if (pickedFiles.isNotEmpty) {
      int remainingSlots = 12 - currentCount;
      if (pickedFiles.length > remainingSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Solo puedes añadir $remainingSlots fotos más. Se han añadido las primeras $remainingSlots.')),
        );
      }

      final filesToProcess = pickedFiles.take(remainingSlots);
      final appDir = await getApplicationDocumentsDirectory();
      
      List<File> newImages = [];
      for (var pickedFile in filesToProcess) {
        final fileName = p.basename(pickedFile.path);
        final targetPath = '${appDir.path}/$fileName';
        
        // Compress and resize
        final result = await FlutterImageCompress.compressAndGetFile(
          pickedFile.path,
          targetPath,
          quality: 70,
          minWidth: 1920,
          minHeight: 1080,
        );

        if (result != null) {
          newImages.add(File(result.path));
        } else {
          // Fallback if compression fails
          final savedImage = await File(pickedFile.path).copy(targetPath);
          newImages.add(savedImage);
        }
      }
      
      setState(() {
        _galleryPhotos.addAll(newImages.map((file) => PhotoDisplay(path: file.path, status: PhotoStatusType.local)));
      });
    }
  }

  final OrderRepository _orderRepo = OrderRepository();

  Future<void> _saveAndQueue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _orderRepo.updateOrderDetails(widget.orden.numeroOrden, {
        'celular': _celularController.text,
        'observaciones_origen': _obsOrigenController.text,
        'observaciones_destino': _obsDestinoController.text,
      });

      final newPhotos = _galleryPhotos.where((p) => p.status == PhotoStatusType.local && p.localId == null).toList();
      for (var photo in newPhotos) {
        await _photoRepo.addPhoto(widget.orden.numeroOrden, photo.path);
      }
      
      UploadService.instance.syncPendingUploads();
      SyncService.instance.sync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos guardados. Se sincronizarán cuando haya conexión.'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop('refresh');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Datos guardados localmente. Se sincronizarán cuando haya conexión.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop('refresh');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Gestionar Orden #${widget.orden.numeroOrden}'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: ConnectionStatusIndicator(),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _celularController,
                          decoration: const InputDecoration(labelText: 'Celular', border: OutlineInputBorder()),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _obsOrigenController,
                          decoration: const InputDecoration(labelText: 'Observaciones de Origen', border: OutlineInputBorder()),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _obsDestinoController,
                          decoration: const InputDecoration(labelText: 'Observaciones de Destino', border: OutlineInputBorder()),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  )
                ),
                const SizedBox(height: 24),
                Text('Fotos de la Orden', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _isLoading ? const Center(child: CircularProgressIndicator()) : _buildPhotoGrid(),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Añadir Foto'),
                  onPressed: _pickImage,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    backgroundColor: Colors.white.withOpacity(0.5)
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Guardar y Sincronizar'),
                  onPressed: _isLoading ? null : _saveAndQueue,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _galleryPhotos.length,
      itemBuilder: (context, index) {
        return _buildPhotoItem(_galleryPhotos[index]);
      },
    );
  }

  Widget _buildPhotoItem(PhotoDisplay photo) {
    Widget imageWidget;
    if (photo.status == PhotoStatusType.uploaded && photo.url != null) {
      imageWidget = Image.network(
        photo.url!,
        fit: BoxFit.cover,
        headers: {'Authorization': 'Bearer $_authToken'},
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.broken_image, color: Colors.red);
        },
      );
    } else {
      imageWidget = Image.file(File(photo.path), fit: BoxFit.cover);
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PhotoViewScreen(photo: photo, authToken: _authToken),
        ));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            if (photo.status == PhotoStatusType.local)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 30),
              ),
            if (photo.status == PhotoStatusType.uploading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            if (photo.status == PhotoStatusType.error)
              GestureDetector(
                onTap: () {
                  if (photo.errorMessage != null) {
                     showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Error de Subida'),
                        content: Text(photo.errorMessage!),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
                        ],
                      ),
                    );
                  }
                },
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Icon(Icons.error_outline, color: Colors.red, size: 30),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
