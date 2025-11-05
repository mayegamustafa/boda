import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:razinshop_rider/config/app_constants.dart';
import 'package:razinshop_rider/services/auth_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_controller.g.dart';

@riverpod
class Login extends _$Login {
  @override
  bool build() {
    return false;
  }

  Future<bool> login({required String phone, required String password}) async {
    try {
      state = true;
      final response = await ref
          .read(authServiceProvider)
          .login(phone: phone, password: password);
          
      if (response.statusCode == 200) {
        // Safely access nested response data
        if (response.data != null && 
            response.data is Map &&
            response.data['data'] != null &&
            response.data['data'] is Map &&
            response.data['data']['access'] != null &&
            response.data['data']['access'] is Map) {
          
          final token = response.data['data']['access']['token'];
          if (token != null) {
            Box authBox = Hive.box(AppConstants.authBox);
            authBox.put(AppConstants.authToken, token.toString());
            state = false;
            return true;
          }
        }
      }
      state = false;
      return false;
    } catch (e) {
      state = false;
      return false;
    }
  }
}

@riverpod
class SendOTP extends _$SendOTP {
  @override
  bool build() {
    return false;
  }

  Future<String?> sendOTP({
    required String phone,
    required bool isForgetPass,
  }) async {
    try {
      state = true;
      final response = await ref
          .read(authServiceProvider)
          .sendOTP(phone: phone, isForgetPass: isForgetPass);
      state = false;
      
      if (response.statusCode == 200) {
        // Safely access the OTP from nested response data
        if (response.data != null && 
            response.data is Map &&
            response.data['data'] != null &&
            response.data['data'] is Map) {
          return response.data['data']['otp']?.toString();
        }
      }
      return null;
    } catch (e) {
      state = false;
      return null;
    }
  }
}

@riverpod
class VerifyOTP extends _$VerifyOTP {
  @override
  bool build() {
    return false;
  }

  Future<String?> verifyOTP({
    required String phone,
    required String otp,
  }) async {
    try {
      state = true;
      final response = await ref
          .read(authServiceProvider)
          .verifyOTP(phone: phone, otp: otp);
      state = false;
      
      if (response.statusCode == 200) {
        // Safely access the token from nested response data
        if (response.data != null && 
            response.data is Map &&
            response.data['data'] != null &&
            response.data['data'] is Map) {
          return response.data['data']['token']?.toString();
        }
      }
      return null;
    } catch (e) {
      state = false;
      return null;
    }
  }
}

@riverpod
class Registration extends _$Registration {
  @override
  bool build() {
    return false;
  }

  Future<bool> registration({required Map<String, dynamic> data}) async {
    state = true;
    final response = await ref
        .read(authServiceProvider)
        .registration(data: data);
    if (response.statusCode == 200) {
      state = false;
      return true;
    } else {
      state = false;
      return false;
    }
  }
}

@riverpod
class CheckUserStatus extends _$CheckUserStatus {
  @override
  void build(String arg) async {
    Box authBox = Hive.box(AppConstants.authBox);
    final response = await ref
        .read(authServiceProvider)
        .checkUserStatus(phone: arg);
    if (response.data['data']['user_status'] == true) {
      authBox.delete(AppConstants.isInReview);
    }
  }
}

@riverpod
class LogOut extends _$LogOut {
  @override
  bool build() {
    return false;
  }

  Future<bool> logOut() async {
    final response = await ref.read(authServiceProvider).logOut();
    Box authBox = Hive.box(AppConstants.authBox);
    state = true;
    if (response.statusCode == 200) {
      authBox.delete(AppConstants.authToken);
      authBox.delete(AppConstants.userData);
      state = false;
      return true;
    } else {
      state = false;
      return false;
    }
  }
}

@riverpod
class CreatePassword extends _$CreatePassword {
  @override
  bool build() {
    return false;
  }

  Future<bool> createPassword({required Map<String, dynamic> data}) async {
    state = true;
    final response = await ref
        .read(authServiceProvider)
        .createPassword(data: data);
    if (response.statusCode == 200) {
      state = false;
      return true;
    } else {
      state = false;
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
class UserDetils extends _$UserDetils {
  @override
  Future<void> build() async {
    final response = await ref.read(authServiceProvider).userDetails();
    if (response.statusCode == 200) {
      final data = response.data['data'];
      Box authBox = Hive.box(AppConstants.authBox);
      authBox.put(AppConstants.userData, data);
    }
    throw UnimplementedError();
  }
}

@riverpod
class ChangePassword extends _$ChangePassword {
  @override
  bool build() {
    return false;
  }

  Future<bool> changePassword({required Map<String, dynamic> data}) async {
    state = true;
    final response = await ref
        .read(authServiceProvider)
        .changePassword(data: data);
    if (response.statusCode == 200) {
      state = false;
      return true;
    } else {
      state = false;
      return false;
    }
  }
}

@riverpod
class CheckPhoneAndEmailProvider extends _$CheckPhoneAndEmailProvider {
  @override
  bool build() {
    return false;
  }

  Future<Map<String, dynamic>> checkPhoneAndEmail({
    required String email,
    required String phone,
  }) async {
    try {
      state = true;
      final response = await ref
          .read(authServiceProvider)
          .checkPhoneAndEmail(email: email, phone: phone);
      state = false;
      final status = response.statusCode == 200;
      return {'status': status, 'message': response.data['data']['message']};
    } catch (e) {
      state = false;
      return {'status': false, 'message': e.toString()};
    }
  }
}

class ValidationNotifier extends StateNotifier<bool> {
  final Ref ref;

  ValidationNotifier(this.ref) : super(false);
  Future<Map<String, dynamic>> checkPhoneAndEmail({
    required String email,
    required String phone,
  }) async {
    try {
      state = true;
      final response = await ref
          .read(authServiceProvider)
          .checkPhoneAndEmail(email: email, phone: phone);
      state = false;
      final status = response.statusCode == 200;
      
      // Safely access the message from response
      String message = 'Unknown error occurred';
      if (response.data != null && response.data is Map) {
        message = response.data['message']?.toString() ?? 'No message provided';
      }
      
      return {'status': status, 'message': message};
    } catch (e) {
      state = false;
      // More detailed error handling
      String errorMessage = 'Registration validation failed';
      if (e is DioException) {
        if (e.response?.data != null && e.response?.data is Map) {
          errorMessage = e.response?.data['message']?.toString() ?? 'API error occurred';
        } else {
          errorMessage = e.message ?? 'Network error occurred';
        }
      } else {
        errorMessage = e.toString();
      }
      return {'status': false, 'message': errorMessage};
    }
  }
}

final validationProvider = StateNotifierProvider<ValidationNotifier, bool>(
  (ref) => ValidationNotifier(ref),
);

@riverpod
class UpdateProfile extends _$UpdateProfile {
  @override
  bool build() {
    return false;
  }

  Future<bool> updateProfile({required Map<String, dynamic> data}) async {
    state = true;
    final response = await ref
        .read(authServiceProvider)
        .updateProfile(data: data);
    if (response.statusCode == 200) {
      state = false;
      return true;
    } else {
      state = false;
      return false;
    }
  }
}
