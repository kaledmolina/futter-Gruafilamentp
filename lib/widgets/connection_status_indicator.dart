import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../services/sync_service.dart';

class ConnectionStatusIndicator extends StatefulWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  State<ConnectionStatusIndicator> createState() => _ConnectionStatusIndicatorState();
}

class _ConnectionStatusIndicatorState extends State<ConnectionStatusIndicator> {
  bool _isOnline = true;
  SyncStatus _syncStatus = SyncStatus.idle;
  int _pendingCount = 0;
  StreamSubscription? _connectivitySubscription;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _checkSyncStatus();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      _checkConnection();
    });
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkSyncStatus();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final result = await Connectivity().checkConnectivity();
    final isOnline = result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.wifi);
    if (mounted && _isOnline != isOnline) {
      setState(() => _isOnline = isOnline);
    }
  }

  Future<void> _checkSyncStatus() async {
    if (!mounted) return;
    final status = await SyncService.instance.getSyncStatus();
    final count = await SyncService.instance.getPendingOperationsCount();
    if (mounted && (_syncStatus != status || _pendingCount != count)) {
      setState(() {
        _syncStatus = status;
        _pendingCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.wifi_off, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text('Sin conexión', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      );
    }

    if (_syncStatus == SyncStatus.syncing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 4),
            Text('Sincronizando...', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      );
    }

    if (_pendingCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_upload, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text('$_pendingCount pendiente${_pendingCount > 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.cloud_done, color: Colors.white, size: 16),
          SizedBox(width: 4),
          Text('Sincronizado', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

