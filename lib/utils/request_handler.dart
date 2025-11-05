import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:razinshop_rider/config/app_constants.dart';
import 'package:razinshop_rider/routers.dart';
import 'package:razinshop_rider/utils/global_function.dart';

void addApiInterceptors(Dio dio) {
  dio.options.connectTimeout = const Duration(seconds: 30);
  dio.options.receiveTimeout = const Duration(seconds: 30);
  dio.options.sendTimeout = const Duration(seconds: 30);
  dio.options.headers['Accept'] = 'application/json';
  // Note: Don't set Content-Type for multipart forms - Dio handles this automatically

  // logger
  dio.interceptors.add(PrettyDioLogger(
    requestHeader: true,
    requestBody: true,
    responseBody: true,
    responseHeader: false,
    error: true,
    compact: true,
    maxWidth: 90,
  ));

  // respone handler
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final authBox = Hive.box(AppConstants.authBox);
        final token = authBox.get(AppConstants.authToken);
        options.headers['Authorization'] = "Bearer $token";
        handler.next(options);
      },
      onResponse: (response, handler) {
        var message = response.data['message'];

        // Sanitize server messages: avoid exposing stack traces or internal
        // server errors to end users. If the message looks like a stack trace
        // or contains internal PHP class paths, replace with a generic text.
        if (message is String) {
          final lower = message.toLowerCase();
          final looksLikeStack = lower.contains('app\\') ||
              lower.contains('repositories') ||
              lower.contains('argument#') ||
              lower.contains('stacktrace') ||
              message.length > 300;
          if (looksLikeStack) {
            message = 'Server error occurred. Please contact support.';
          }
        }

        switch (response.statusCode) {
          case 401:
            Box authBox = Hive.box(AppConstants.authBox);
            authBox.delete(AppConstants.authToken);
            GlobalFunction.navigatorKey.currentState
                ?.pushNamedAndRemoveUntil(Routes.login, (route) => false);
            GlobalFunction.showCustomSnackbar(
              message: message ?? 'Unauthorized',
              isSuccess: false,
            );
            break;
          case 302:
          case 400:
          case 403:
          case 404:
          case 409:
          case 422:
          case 500:
            GlobalFunction.showCustomSnackbar(
              message: message ?? 'Server error occurred',
              isSuccess: false,
            );
            break;
          default:
            break;
        }
        handler.next(response);
      },
      onError: (error, handler) {
        // Only show error messages for non-background API calls
        final url = error.requestOptions.path;
        final isBackgroundCall = url.contains('/master') || url.contains('/check-user-status');
        
        print('API Error: ${error.type} - ${error.message}');
        print('Request URL: ${error.requestOptions.uri}');
        print('Error Response: ${error.response?.data}');
        
        String errorMessage = 'Network error occurred';
        
        switch (error.type) {
          case DioExceptionType.connectionError:
            errorMessage = 'Connection error. Please check your internet connection.';
            break;
          case DioExceptionType.connectionTimeout:
            errorMessage = 'Connection timeout. Please try again.';
            break;
          case DioExceptionType.receiveTimeout:
            errorMessage = 'Server response timeout. Please try again.';
            break;
          case DioExceptionType.sendTimeout:
            errorMessage = 'Request timeout. Please try again.';
            break;
          case DioExceptionType.badResponse:
            if (error.response?.data != null) {
              try {
                final responseData = error.response!.data;
                String? candidate;
                if (responseData is Map && responseData.containsKey('message')) {
                  candidate = responseData['message'].toString();
                } else if (responseData is String) {
                  candidate = responseData;
                }

                // Sanitize server-provided messages to avoid displaying stack traces
                if (candidate != null) {
                  final lower = candidate.toLowerCase();
                  final looksLikeStack = lower.contains('app\\') ||
                      lower.contains('repositories') ||
                      lower.contains('argument#') ||
                      lower.contains('stacktrace') ||
                      candidate.length > 300;
                  if (looksLikeStack) {
                    errorMessage = 'Server error occurred. Please contact support.';
                  } else {
                    errorMessage = candidate;
                  }
                } else {
                  errorMessage = 'Server error occurred';
                }
              } catch (e) {
                errorMessage = 'Server error occurred';
              }
            } else {
              errorMessage = 'Server error occurred';
            }
            break;
          case DioExceptionType.unknown:
            errorMessage = 'Unknown error occurred. Please try again.';
            break;
          default:
            errorMessage = 'Network error occurred';
            break;
        }
        
        if (!isBackgroundCall) {
          GlobalFunction.showCustomSnackbar(
            message: errorMessage,
            isSuccess: false,
          );
        }
        
        if (error.response != null) {
          final statusCode = error.response!.statusCode;
          switch (statusCode) {
            case 401:
              Box authBox = Hive.box(AppConstants.authBox);
              authBox.delete(AppConstants.authToken);
              GlobalFunction.navigatorKey.currentState
                  ?.pushNamedAndRemoveUntil(Routes.login, (route) => false);
              break;
            default:
              break;
          }
        }
        handler.reject(error);
      },
    ),
  );
}
