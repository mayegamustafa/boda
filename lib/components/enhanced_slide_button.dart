import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:razinshop_rider/config/app_color.dart';
import 'package:razinshop_rider/config/app_text.dart';
import 'package:razinshop_rider/controllers/misc/providers.dart';
import 'package:razinshop_rider/utils/extensions.dart';
import 'package:razinshop_rider/utils/global_function.dart';

// Enhanced Slide Button State Providers
final enhancedSlideButtonLeftPosition = StateProvider<double>((ref) => 0.0);
final enhancedSlideButtonComplete = StateProvider<bool>((ref) => false);
final enhancedSlideButtonLoading = StateProvider<bool>((ref) => false);
final enhancedSlideButtonError = StateProvider<String?>((ref) => null);
final enhancedSlideButtonRetryCount = StateProvider<int>((ref) => 0);

enum SlideButtonState {
  idle,
  sliding,
  loading,
  success,
  error,
  retrying,
}

class EnhancedSlideButton extends ConsumerStatefulWidget {
  final String text;
  final String? loadingText;
  final String? successText;
  final String? errorText;
  final Future<void> Function() onSlideComplete;
  final VoidCallback? onRetry;
  final double width;
  final double height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool hapticFeedback;
  final int maxRetries;
  final Duration animationDuration;

  const EnhancedSlideButton({
    super.key,
    required this.text,
    required this.onSlideComplete,
    this.loadingText,
    this.successText,
    this.errorText,
    this.onRetry,
    this.width = 328,
    this.height = 54,
    this.backgroundColor,
    this.foregroundColor,
    this.textColor,
    this.icon,
    this.hapticFeedback = true,
    this.maxRetries = 3,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  ConsumerState<EnhancedSlideButton> createState() => _EnhancedSlideButtonState();
}

class _EnhancedSlideButtonState extends ConsumerState<EnhancedSlideButton>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  Timer? _resetTimer;
  Timer? _errorResetTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: widget.width - 48.w,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    // Start pulse animation
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    _resetTimer?.cancel();
    _errorResetTimer?.cancel();
    super.dispose();
  }

  SlideButtonState _getCurrentState() {
    final isLoading = ref.read(enhancedSlideButtonLoading);
    final isComplete = ref.read(enhancedSlideButtonComplete);
    final hasError = ref.read(enhancedSlideButtonError) != null;
    final position = ref.read(enhancedSlideButtonLeftPosition);

    if (hasError) return SlideButtonState.error;
    if (isComplete && !isLoading) return SlideButtonState.success;
    if (isLoading) return SlideButtonState.loading;
    if (position > 0 && position < widget.width - 48.w) return SlideButtonState.sliding;
    return SlideButtonState.idle;
  }

  Color _getBackgroundColor() {
    final state = _getCurrentState();
    switch (state) {
      case SlideButtonState.idle:
      case SlideButtonState.sliding:
        return widget.backgroundColor ?? GlobalFunction.sliderButtonStatus(
          widget.text, context,
        ).buttonColor;
      case SlideButtonState.loading:
        return Colors.blue.withOpacity(0.8);
      case SlideButtonState.success:
        return Colors.green.withOpacity(0.8);
      case SlideButtonState.error:
        return Colors.red.withOpacity(0.8);
      case SlideButtonState.retrying:
        return Colors.orange.withOpacity(0.8);
    }
  }

  String _getDisplayText() {
    final state = _getCurrentState();
    final retryCount = ref.read(enhancedSlideButtonRetryCount);
    final error = ref.read(enhancedSlideButtonError);

    switch (state) {
      case SlideButtonState.idle:
      case SlideButtonState.sliding:
        return widget.text;
      case SlideButtonState.loading:
        return widget.loadingText ?? 'Amebaki...';
      case SlideButtonState.success:
        return widget.successText ?? 'Imefanikiwa!';
      case SlideButtonState.error:
        if (retryCount >= widget.maxRetries) {
          return 'Imeshindwa. Jaribu tena baadaye';
        }
        return widget.errorText ?? 
               (error?.contains('network') == true 
                 ? 'Hakuna mtandao. Bonyeza ujaribu tena' 
                 : 'Imeshindwa. Bonyeza ujaribu tena');
      case SlideButtonState.retrying:
        return 'Inajaribu tena... (${retryCount + 1}/${widget.maxRetries})';
    }
  }

  Widget _getSlideIcon() {
    final state = _getCurrentState();
    
    switch (state) {
      case SlideButtonState.idle:
      case SlideButtonState.sliding:
        if (widget.icon != null) {
          return Icon(
            widget.icon,
            color: widget.foregroundColor ?? Colors.grey[600],
            size: 20.sp,
          );
        } else {
          return GlobalFunction.slideButtonIcon(widget.text);
        }
      case SlideButtonState.loading:
      case SlideButtonState.retrying:
        return SizedBox(
          width: 20.sp,
          height: 20.sp,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.foregroundColor ?? Colors.white,
            ),
          ),
        );
      case SlideButtonState.success:
        return Icon(
          Icons.check,
          color: Colors.white,
          size: 20.sp,
        );
      case SlideButtonState.error:
        return Icon(
          Icons.refresh,
          color: Colors.white,
          size: 20.sp,
        );
    }
  }

  void _handleSlideStart() {
    if (_getCurrentState() != SlideButtonState.idle) return;

    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    // Clear any previous errors
    ref.read(enhancedSlideButtonError.notifier).state = null;
  }

  void _handleSlideUpdate(DragUpdateDetails details) {
    final currentState = _getCurrentState();
    if (currentState != SlideButtonState.idle && 
        currentState != SlideButtonState.sliding) {
      return;
    }

    final currentPosition = ref.read(enhancedSlideButtonLeftPosition);
    final newPosition = (currentPosition + details.delta.dx)
        .clamp(0.0, widget.width - 48.w);
    
    ref.read(enhancedSlideButtonLeftPosition.notifier).state = newPosition;
  }

  void _handleSlideEnd(DragEndDetails details) async {
    final currentState = _getCurrentState();
    if (currentState != SlideButtonState.sliding && 
        currentState != SlideButtonState.idle) {
      return;
    }

    final position = ref.read(enhancedSlideButtonLeftPosition);
    final threshold = (widget.width - 48.w) * 0.8; // 80% completion required

    if (position >= threshold) {
      // Complete the slide
      await _completeSlide();
    } else {
      // Reset to start
      await _resetSlide();
    }
  }

  Future<void> _completeSlide() async {
    if (widget.hapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    // Animate to complete position
    ref.read(enhancedSlideButtonLeftPosition.notifier).state = widget.width - 48.w;
    ref.read(enhancedSlideButtonComplete.notifier).state = true;
    ref.read(enhancedSlideButtonLoading.notifier).state = true;

    await _slideController.forward();

    try {
      // Execute the callback
      await widget.onSlideComplete();
      
      // Success state
      if (widget.hapticFeedback) {
        HapticFeedback.heavyImpact();
      }

      // Show success for 2 seconds then reset
      _resetTimer = Timer(const Duration(seconds: 2), () {
        _resetToIdle();
      });

    } catch (error) {
      // Error state
      if (widget.hapticFeedback) {
        HapticFeedback.heavyImpact();
      }

      ref.read(enhancedSlideButtonError.notifier).state = error.toString();
      ref.read(enhancedSlideButtonLoading.notifier).state = false;
      
      // Shake animation on error
      _shakeController.forward().then((_) => _shakeController.reset());

      // Auto-reset error after 5 seconds if not manually retried
      _errorResetTimer = Timer(const Duration(seconds: 5), () {
        final retryCount = ref.read(enhancedSlideButtonRetryCount);
        if (retryCount >= widget.maxRetries) {
          _resetToIdle();
        }
      });
    }
  }

  Future<void> _resetSlide() async {
    await _slideController.reverse();
    ref.read(enhancedSlideButtonLeftPosition.notifier).state = 0.0;
  }

  void _resetToIdle() {
    ref.read(enhancedSlideButtonLeftPosition.notifier).state = 0.0;
    ref.read(enhancedSlideButtonComplete.notifier).state = false;
    ref.read(enhancedSlideButtonLoading.notifier).state = false;
    ref.read(enhancedSlideButtonError.notifier).state = null;
    ref.read(enhancedSlideButtonRetryCount.notifier).state = 0;
    _slideController.reset();
  }

  Future<void> _handleRetry() async {
    final retryCount = ref.read(enhancedSlideButtonRetryCount);
    
    if (retryCount >= widget.maxRetries) {
      _resetToIdle();
      return;
    }

    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    // Increment retry count
    ref.read(enhancedSlideButtonRetryCount.notifier).state = retryCount + 1;
    
    // Clear error and set loading
    ref.read(enhancedSlideButtonError.notifier).state = null;
    ref.read(enhancedSlideButtonLoading.notifier).state = true;

    try {
      // Execute retry callback if provided, otherwise use original callback
      if (widget.onRetry != null) {
        widget.onRetry!();
      } else {
        await widget.onSlideComplete();
      }

      // Success - reset retry count
      ref.read(enhancedSlideButtonRetryCount.notifier).state = 0;
      
      if (widget.hapticFeedback) {
        HapticFeedback.heavyImpact();
      }

      _resetTimer = Timer(const Duration(seconds: 2), () {
        _resetToIdle();
      });

    } catch (error) {
      ref.read(enhancedSlideButtonError.notifier).state = error.toString();
      ref.read(enhancedSlideButtonLoading.notifier).state = false;
      
      _shakeController.forward().then((_) => _shakeController.reset());
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(enhancedSlideButtonLeftPosition);
    final state = _getCurrentState();
    
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Container(
            width: widget.width.w,
            height: widget.height.h,
            padding: EdgeInsets.symmetric(horizontal: 4.r, vertical: 3.r),
            decoration: BoxDecoration(
              color: _getBackgroundColor(),
              borderRadius: BorderRadius.circular(27.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background text
                Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: position < (widget.width - 48.w) * 0.5 ? 1.0 : 0.0,
                    child: Text(
                      _getDisplayText(),
                      style: AppTextStyle.normalBody.copyWith(
                        color: widget.textColor ?? 
                               (context.isDark ? Colors.white : Colors.black87),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                
                // Sliding button
                AnimatedPositioned(
                  duration: state == SlideButtonState.sliding 
                      ? Duration.zero 
                      : widget.animationDuration,
                  left: position,
                  top: 0,
                  child: GestureDetector(
                    onPanStart: state == SlideButtonState.error 
                        ? null 
                        : (_) => _handleSlideStart(),
                    onPanUpdate: state == SlideButtonState.error 
                        ? null 
                        : _handleSlideUpdate,
                    onPanEnd: state == SlideButtonState.error 
                        ? null 
                        : _handleSlideEnd,
                    onTap: state == SlideButtonState.error 
                        ? _handleRetry 
                        : null,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: state == SlideButtonState.idle 
                              ? _pulseAnimation.value 
                              : 1.0,
                          child: Container(
                            height: 48.r,
                            width: 48.r,
                            decoration: BoxDecoration(
                              color: context.isDark
                                  ? Colors.grey.withOpacity(0.6)
                                  : AppColor.whiteColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _getSlideIcon(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Usage Helper Extension
extension SlideButtonHelpers on WidgetRef {
  void resetEnhancedSlideButton() {
    read(enhancedSlideButtonLeftPosition.notifier).state = 0.0;
    read(enhancedSlideButtonComplete.notifier).state = false;
    read(enhancedSlideButtonLoading.notifier).state = false;
    read(enhancedSlideButtonError.notifier).state = null;
    read(enhancedSlideButtonRetryCount.notifier).state = 0;
  }
}