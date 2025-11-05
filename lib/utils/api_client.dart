import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razinshop_rider/utils/request_handler.dart';

final apiClientProvider = Provider((ref) => ApiClient());

class ApiClient {
  final Dio _dio = Dio();

  ApiClient() {
    addApiInterceptors(_dio);
  }

  Map<String, dynamic> defaultHeaders = {
    HttpHeaders.authorizationHeader: null,
  };

  Future<Response> get(String url, {Map<String, dynamic>? query}) async {
    return _dio.get(
      url,
      queryParameters: query,
      options: Options(headers: defaultHeaders),
    );
  }

  Future<Response> post(
    String url, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    
    // Create proper headers for multipart data
    Map<String, dynamic> requestHeaders = Map.from(defaultHeaders);
    if (headers != null) {
      requestHeaders.addAll(headers);
    }
    
    // Remove Content-Type for FormData - Dio will set it automatically
    if (data is FormData) {
      requestHeaders.remove('Content-Type');
    }
    
    print('POST Request to: $url');
    print('Headers: $requestHeaders');
    print('Data type: ${data.runtimeType}');
    if (data is FormData) {
      print('FormData fields: ${data.fields.map((f) => '${f.key}: ${f.value}')}');
      print('FormData files: ${data.files.map((f) => '${f.key}: ${f.value.filename}')}');
    }
    
    return _dio.post(
      url,
      data: data,
      options: Options(
        headers: requestHeaders,
        followRedirects: false,
        validateStatus: ((status) {
          return status! <= 500;
        }),
      ),
    );
  }

  Future<Response> put(
    String url, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    return _dio.put(
      url,
      data: data,
      options: Options(
        headers: headers ?? defaultHeaders,
        followRedirects: false,
        validateStatus: ((status) {
          return status! <= 500;
        }),
      ),
    );
  }

  Future<Response> delete(
    String url, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? headers,
  }) async {
    return _dio.delete(
      url,
      data: data,
      options: Options(
        headers: headers ?? defaultHeaders,
        followRedirects: false,
        validateStatus: ((status) {
          return status! <= 500;
        }),
      ),
    );
  }

  // void updateToken({required String token}) {
  //   defaultHeaders[HttpHeaders.authorizationHeader] = 'Bearer $token';
  //   debugPrint(
  //       'Update Token:${defaultHeaders[HttpHeaders.authorizationHeader]}');
  // }
}
