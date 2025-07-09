import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/orden_model.dart';
import '../models/photo_status_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/upload_service.dart';
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

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    try {
      final uploaded = await ApiService().getUploadedPhotos(widget.orden.id);
      final pending = await DatabaseService.instance.getPendingPhotosForOrder(widget.orden.id);

      final List<PhotoDisplay> combinedList = [];
      combinedList.addAll(uploaded.map((p) => PhotoDisplay(
        remoteId: p['id'], 
        path: p['path'], 
        url: p['url'],
        status: PhotoStatusType.uploaded
      )));
      combinedList.addAll(pending.map((p) => PhotoDisplay(localId: p['id'], path: p['image_path'], status: PhotoStatusType.local)));
      
      if (mounted) {
        setState(() {
          _galleryPhotos = combinedList;
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
    if (_galleryPhotos.length >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pueden subir más de 12 fotos.')),
      );
      return;
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(pickedFile.path);
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');
      
      setState(() {
        _galleryPhotos.add(PhotoDisplay(path: savedImage.path, status: PhotoStatusType.local));
      });
    }
  }

  Future<void> _saveAndQueue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ApiService().updateDetails(widget.orden.id, {
        'celular': _celularController.text,
        'observaciones_origen': _obsOrigenController.text,
        'observaciones_destino': _obsDestinoController.text,
      });

      final newPhotos = _galleryPhotos.where((p) => p.status == PhotoStatusType.local && p.localId == null).toList();
      for (var photo in newPhotos) {
        await DatabaseService.instance.addPendingPhoto(widget.orden.id, photo.path);
      }
      
      UploadService.instance.syncPendingUploads();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos guardados. Las fotos se subirán en segundo plano.'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop('refresh');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gestionar Orden #${widget.orden.numeroOrden}')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 24),
              const Text('Fotos de la Orden', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _isLoading ? const Center(child: CircularProgressIndicator()) : _buildPhotoGrid(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Añadir Foto'),
                onPressed: _pickImage,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveAndQueue,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading ? const CircularProgressIndicator() : const Text('Guardar y Sincronizar'),
              ),
            ],
          ),
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
    // CORRECCIÓN: Se construye la URL correcta para las fotos subidas.
    if (photo.status == PhotoStatusType.uploaded && photo.remoteId != null) {
      final secureUrl = '${ApiService.baseUrl}/v1/private-fotos/${photo.remoteId}';
      imageWidget = Image.network(
        secureUrl,
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
        borderRadius: BorderRadius.circular(8.0),
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
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Icon(Icons.error_outline, color: Colors.red, size: 30),
              ),
          ],
        ),
      ),
    );
  }
}



