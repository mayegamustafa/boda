import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:razinshop_rider/config/app_constants.dart';

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  static const String _telemetryBox = 'telemetry_logs';
  static const int _maxLocalLogs = 100; // Keep last 100 logs locally
  
  late Box _telemetryBoxInstance;
  late Map<String, dynamic> _deviceInfo;
  late Map<String, dynamic> _appInfo;

  /// Initialize telemetry service
  Future<void> initialize() async {
    try {
      _telemetryBoxInstance = await Hive.openBox(_telemetryBox);
      await _gatherDeviceInfo();
      await _gatherAppInfo();
      
      // Log initialization
      await logEvent(
        event: 'telemetry_initialized',
        level: TelemetryLevel.info,
        data: {'initialized_at': DateTime.now().toIso8601String()},
      );
    } catch (e) {
      debugPrint('Failed to initialize telemetry: $e');
    }
  }

  /// Gather device information
  Future<void> _gatherDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceInfo = {
          'platform': 'android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
          'sdk_int': androidInfo.version.sdkInt,
          'board': androidInfo.board,
          'device': androidInfo.device,
          'display': androidInfo.display,
          'fingerprint': _sanitizeFingerprint(androidInfo.fingerprint),
          'hardware': androidInfo.hardware,
          'host': androidInfo.host,
          'id': androidInfo.id,
          'product': androidInfo.product,
          'supported_32_bit_abis': androidInfo.supported32BitAbis,
          'supported_64_bit_abis': androidInfo.supported64BitAbis,
          'supported_abis': androidInfo.supportedAbis,
          'tags': androidInfo.tags,
          'type': androidInfo.type,
          'is_physical_device': androidInfo.isPhysicalDevice,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceInfo = {
          'platform': 'ios',
          'name': iosInfo.name,
          'system_name': iosInfo.systemName,
          'system_version': iosInfo.systemVersion,
          'model': iosInfo.model,
          'localized_model': iosInfo.localizedModel,
          'identifier_for_vendor': iosInfo.identifierForVendor,
          'is_physical_device': iosInfo.isPhysicalDevice,
          'utsname': {
            'sysname': iosInfo.utsname.sysname,
            'nodename': iosInfo.utsname.nodename,
            'release': iosInfo.utsname.release,
            'version': iosInfo.utsname.version,
            'machine': iosInfo.utsname.machine,
          }
        };
      } else {
        _deviceInfo = {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
        };
      }
    } catch (e) {
      _deviceInfo = {
        'platform': 'unknown',
        'error': 'Failed to gather device info: $e',
      };
    }
  }

  /// Gather app information
  Future<void> _gatherAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appInfo = {
        'app_name': packageInfo.appName,
        'package_name': packageInfo.packageName,
        'version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
        'build_signature': packageInfo.buildSignature,
      };
    } catch (e) {
      _appInfo = {
        'app_name': 'Total Ride',
        'package_name': 'rider.readyecommerce.app',
        'version': 'unknown',
        'build_number': 'unknown',
        'error': 'Failed to gather app info: $e',
      };
    }
  }

  /// Sanitize fingerprint for privacy
  String _sanitizeFingerprint(String fingerprint) {
    // Keep only brand, model, and version info, remove personal identifiers
    final parts = fingerprint.split(':');
    if (parts.length >= 3) {
      return '${parts[0]}:${parts[1]}:${parts[2]}:***';
    }
    return 'sanitized';
  }

  /// Log a telemetry event
  Future<void> logEvent({
    required String event,
    required TelemetryLevel level,
    Map<String, dynamic>? data,
    StackTrace? stackTrace,
    String? userId,
    String? sessionId,
    Map<String, String>? tags,
  }) async {
    try {
      final logEntry = TelemetryLogEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        event: event,
        level: level,
        data: data ?? {},
        stackTrace: stackTrace?.toString(),
        deviceInfo: _deviceInfo,
        appInfo: _appInfo,
        userId: userId ?? await _getCurrentUserId(),
        sessionId: sessionId ?? await _getCurrentSessionId(),
        tags: tags ?? {},
      );

      // Store locally
      await _storeLogEntry(logEntry);

      // Clean up old logs
      await _cleanupOldLogs();

      // In debug mode, print to console
      if (kDebugMode) {
        _printLogEntry(logEntry);
      }

    } catch (e) {
      debugPrint('Failed to log telemetry event: $e');
    }
  }

  /// Log an error with enhanced context
  Future<void> logError({
    required String error,
    required StackTrace stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
    String? userId,
    String? sessionId,
    TelemetryLevel level = TelemetryLevel.error,
  }) async {
    final sanitizedError = _sanitizeErrorMessage(error);
    
    await logEvent(
      event: 'app_error',
      level: level,
      data: {
        'error': sanitizedError,
        'context': context,
        'original_error_length': error.length,
        'has_stack_trace': stackTrace.toString().isNotEmpty,
        ...?additionalData,
      },
      stackTrace: stackTrace,
      userId: userId,
      sessionId: sessionId,
      tags: {
        'error_type': _categorizeError(error),
        'severity': level.name,
      },
    );
  }

  /// Log network errors specifically
  Future<void> logNetworkError({
    required String endpoint,
    required int statusCode,
    required String error,
    String? requestMethod,
    String? requestBody,
    String? responseBody,
    Duration? duration,
  }) async {
    await logEvent(
      event: 'network_error',
      level: TelemetryLevel.error,
      data: {
        'endpoint': endpoint,
        'status_code': statusCode,
        'error': _sanitizeErrorMessage(error),
        'request_method': requestMethod,
        'request_body_size': requestBody?.length,
        'response_body_size': responseBody?.length,
        'duration_ms': duration?.inMilliseconds,
        'sanitized_response': _sanitizeNetworkResponse(responseBody),
      },
      tags: {
        'error_type': 'network',
        'status_category': _getStatusCategory(statusCode),
      },
    );
  }

  /// Log user actions for debugging
  Future<void> logUserAction({
    required String action,
    String? screen,
    Map<String, dynamic>? data,
    String? userId,
  }) async {
    await logEvent(
      event: 'user_action',
      level: TelemetryLevel.info,
      data: {
        'action': action,
        'screen': screen,
        ...?data,
      },
      userId: userId,
      tags: {
        'event_type': 'user_action',
        'screen': screen ?? 'unknown',
      },
    );
  }

  /// Store log entry locally
  Future<void> _storeLogEntry(TelemetryLogEntry entry) async {
    try {
      final logs = _telemetryBoxInstance.get('logs', defaultValue: <String>[]) as List<String>;
      logs.add(jsonEncode(entry.toMap()));
      await _telemetryBoxInstance.put('logs', logs);
    } catch (e) {
      debugPrint('Failed to store telemetry log: $e');
    }
  }

  /// Clean up old logs to prevent storage bloat
  Future<void> _cleanupOldLogs() async {
    try {
      final logs = _telemetryBoxInstance.get('logs', defaultValue: <String>[]) as List<String>;
      if (logs.length > _maxLocalLogs) {
        final trimmedLogs = logs.sublist(logs.length - _maxLocalLogs);
        await _telemetryBoxInstance.put('logs', trimmedLogs);
      }
    } catch (e) {
      debugPrint('Failed to cleanup telemetry logs: $e');
    }
  }

  /// Print log entry to console in debug mode
  void _printLogEntry(TelemetryLogEntry entry) {
    final levelEmoji = {
      TelemetryLevel.debug: '🔍',
      TelemetryLevel.info: 'ℹ️',
      TelemetryLevel.warning: '⚠️',
      TelemetryLevel.error: '❌',
      TelemetryLevel.critical: '🚨',
    };

    print('${levelEmoji[entry.level]} [${entry.level.name.toUpperCase()}] ${entry.event}');
    if (entry.data.isNotEmpty) {
      print('   Data: ${entry.data}');
    }
    if (entry.tags.isNotEmpty) {
      print('   Tags: ${entry.tags}');
    }
  }

  /// Sanitize error messages to remove sensitive information
  String _sanitizeErrorMessage(String error) {
    // Remove stack traces from user-visible errors
    if (error.contains('StackTrace:') || error.contains('\n#')) {
      final lines = error.split('\n');
      final errorLine = lines.first;
      return errorLine.length > 200 ? '${errorLine.substring(0, 200)}...' : errorLine;
    }

    // Remove sensitive patterns
    String sanitized = error
        .replaceAll(RegExp(r'password["\s]*[:=]["\s]*[^"\s,}]*', caseSensitive: false), 'password":"***"')
        .replaceAll(RegExp(r'token["\s]*[:=]["\s]*[^"\s,}]*', caseSensitive: false), 'token":"***"')
        .replaceAll(RegExp(r'key["\s]*[:=]["\s]*[^"\s,}]*', caseSensitive: false), 'key":"***"')
        .replaceAll(RegExp(r'auth["\s]*[:=]["\s]*[^"\s,}]*', caseSensitive: false), 'auth":"***"');

    return sanitized.length > 500 ? '${sanitized.substring(0, 500)}...' : sanitized;
  }

  /// Sanitize network response for logging
  String? _sanitizeNetworkResponse(String? response) {
    if (response == null || response.isEmpty) return null;
    
    try {
      // If it's JSON, try to parse and sanitize sensitive fields
      final json = jsonDecode(response);
      if (json is Map<String, dynamic>) {
        final sanitized = Map<String, dynamic>.from(json);
        _sanitizeMap(sanitized);
        return jsonEncode(sanitized);
      }
    } catch (e) {
      // Not JSON, just truncate if too long
    }
    
    return response.length > 1000 ? '${response.substring(0, 1000)}...' : response;
  }

  /// Recursively sanitize sensitive fields in maps
  void _sanitizeMap(Map<String, dynamic> map) {
    final sensitiveKeys = ['password', 'token', 'key', 'auth', 'secret', 'credential'];
    
    for (final key in map.keys.toList()) {
      if (sensitiveKeys.any((sensitive) => key.toLowerCase().contains(sensitive))) {
        map[key] = '***';
      } else if (map[key] is Map<String, dynamic>) {
        _sanitizeMap(map[key]);
      } else if (map[key] is List) {
        final list = map[key] as List;
        for (int i = 0; i < list.length; i++) {
          if (list[i] is Map<String, dynamic>) {
            _sanitizeMap(list[i]);
          }
        }
      }
    }
  }

  /// Categorize error types for better analytics
  String _categorizeError(String error) {
    final lowerError = error.toLowerCase();
    
    if (lowerError.contains('network') || lowerError.contains('connection') || 
        lowerError.contains('socket') || lowerError.contains('timeout')) {
      return 'network';
    }
    
    if (lowerError.contains('permission') || lowerError.contains('denied')) {
      return 'permission';
    }
    
    if (lowerError.contains('format') || lowerError.contains('parse') ||
        lowerError.contains('json') || lowerError.contains('decode')) {
      return 'data_format';
    }
    
    if (lowerError.contains('null') || lowerError.contains('undefined')) {
      return 'null_reference';
    }
    
    if (lowerError.contains('file') || lowerError.contains('directory') ||
        lowerError.contains('path')) {
      return 'file_system';
    }
    
    return 'general';
  }

  /// Get HTTP status category for analytics
  String _getStatusCategory(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return 'success';
    if (statusCode >= 300 && statusCode < 400) return 'redirect';
    if (statusCode >= 400 && statusCode < 500) return 'client_error';
    if (statusCode >= 500) return 'server_error';
    return 'unknown';
  }

  /// Get current user ID from storage
  Future<String?> _getCurrentUserId() async {
    try {
      final authBox = Hive.box(AppConstants.authBox);
      return authBox.get('user_id')?.toString();
    } catch (e) {
      return null;
    }
  }

  /// Get or generate session ID
  Future<String> _getCurrentSessionId() async {
    try {
      final sessionId = _telemetryBoxInstance.get('session_id');
      if (sessionId != null) return sessionId;
      
      final newSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      await _telemetryBoxInstance.put('session_id', newSessionId);
      return newSessionId;
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Get all logs for debugging or export
  Future<List<TelemetryLogEntry>> getAllLogs() async {
    try {
      final logs = _telemetryBoxInstance.get('logs', defaultValue: <String>[]) as List<String>;
      return logs.map((logJson) {
        final map = jsonDecode(logJson) as Map<String, dynamic>;
        return TelemetryLogEntry.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint('Failed to get telemetry logs: $e');
      return [];
    }
  }

  /// Export logs as JSON string for sending to backend
  Future<String> exportLogs({int? limit}) async {
    try {
      final logs = await getAllLogs();
      final logsToExport = limit != null && logs.length > limit 
          ? logs.sublist(logs.length - limit)
          : logs;
      
      return jsonEncode({
        'logs': logsToExport.map((log) => log.toMap()).toList(),
        'exported_at': DateTime.now().toIso8601String(),
        'total_logs': logsToExport.length,
      });
    } catch (e) {
      return jsonEncode({
        'error': 'Failed to export logs: $e',
        'exported_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    try {
      await _telemetryBoxInstance.put('logs', <String>[]);
      await logEvent(
        event: 'logs_cleared',
        level: TelemetryLevel.info,
        data: {'cleared_at': DateTime.now().toIso8601String()},
      );
    } catch (e) {
      debugPrint('Failed to clear telemetry logs: $e');
    }
  }
}

/// Telemetry log levels
enum TelemetryLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Telemetry log entry model
class TelemetryLogEntry {
  final String id;
  final DateTime timestamp;
  final String event;
  final TelemetryLevel level;
  final Map<String, dynamic> data;
  final String? stackTrace;
  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic> appInfo;
  final String? userId;
  final String sessionId;
  final Map<String, String> tags;

  TelemetryLogEntry({
    required this.id,
    required this.timestamp,
    required this.event,
    required this.level,
    required this.data,
    this.stackTrace,
    required this.deviceInfo,
    required this.appInfo,
    this.userId,
    required this.sessionId,
    required this.tags,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'event': event,
      'level': level.name,
      'data': data,
      'stack_trace': stackTrace,
      'device_info': deviceInfo,
      'app_info': appInfo,
      'user_id': userId,
      'session_id': sessionId,
      'tags': tags,
    };
  }

  factory TelemetryLogEntry.fromMap(Map<String, dynamic> map) {
    return TelemetryLogEntry(
      id: map['id'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      event: map['event'] ?? '',
      level: TelemetryLevel.values.firstWhere(
        (level) => level.name == map['level'],
        orElse: () => TelemetryLevel.info,
      ),
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      stackTrace: map['stack_trace'],
      deviceInfo: Map<String, dynamic>.from(map['device_info'] ?? {}),
      appInfo: Map<String, dynamic>.from(map['app_info'] ?? {}),
      userId: map['user_id'],
      sessionId: map['session_id'] ?? '',
      tags: Map<String, String>.from(map['tags'] ?? {}),
    );
  }
}