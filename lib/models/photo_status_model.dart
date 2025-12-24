enum PhotoStatusType { local, uploaded, uploading, error }

class PhotoDisplay {
  final int? localId;
  final int? remoteId;
  final String path; // Ruta local o relativa del servidor
  final String? url;  // URL completa y segura para ver la foto
  final PhotoStatusType status;
  final String? errorMessage;

  PhotoDisplay({
    this.localId,
    this.remoteId,
    required this.path,
    this.url,
    required this.status,
    this.errorMessage,
  });
}