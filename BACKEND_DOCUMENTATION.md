# Total Ride Backend Documentation & Error Analysis

## Overview
This document provides comprehensive guidance for backend developers working on the Total Ride delivery application. It includes error analysis, recommended fixes, and best practices for a production-ready system.

## Table of Contents
1. [Critical Issues Identified](#critical-issues-identified)
2. [Error Analysis](#error-analysis)
3. [Recommended Backend Fixes](#recommended-backend-fixes)
4. [API Response Standards](#api-response-standards)
5. [Error Handling Best Practices](#error-handling-best-practices)
6. [Security Considerations](#security-considerations)
7. [Performance Optimization](#performance-optimization)
8. [Monitoring & Logging](#monitoring--logging)

## Critical Issues Identified

### 1. Wallet Repository Error Exposure
**Issue**: Stack traces from `App\Repositories\walletRepository::updateByRequest()` are being exposed to mobile clients.

**Impact**: 
- Poor user experience
- Security vulnerability (code structure exposure)
- Debugging confusion for riders

**Client-Side Error**:
```
App\Repositories\walletRepository::updateByRequest(): Argument #1 ($request) must be of type Illuminate\Http\Request, array given, called in /path/to/controller.php on line 123
```

### 2. GPS Coordinate Issues
**Issue**: Missing or incorrect latitude/longitude coordinates in API responses.

**Impact**:
- Navigation to wrong locations
- Failed order deliveries
- Poor rider experience

### 3. Notification System Gaps
**Issue**: No real-time push notification system for instant order assignments.

**Impact**:
- Delayed order notifications
- Reduced operational efficiency
- Higher customer wait times

## Error Analysis

### WalletRepository Error Deep Dive

#### Root Cause
The error indicates a type mismatch in the `updateByRequest()` method where an array is being passed instead of a `Request` object.

#### Affected Code Pattern (Laravel PHP):
```php
// ❌ INCORRECT - Passing array instead of Request object
public function someController(Request $request) {
    $data = $request->all();
    $this->walletRepository->updateByRequest($data); // Error here
}

// ✅ CORRECT - Pass Request object directly
public function someController(Request $request) {
    $this->walletRepository->updateByRequest($request);
}
```

#### Common Locations
- Order completion endpoints
- Payment processing
- Cash collection after delivery

### GPS Coordinate Issues

#### Missing Fields in Database Schema
Ensure these fields exist in relevant tables:

```sql
-- Orders table
ALTER TABLE orders ADD COLUMN pickup_latitude DECIMAL(10, 8) NULL;
ALTER TABLE orders ADD COLUMN pickup_longitude DECIMAL(11, 8) NULL;
ALTER TABLE orders ADD COLUMN delivery_latitude DECIMAL(10, 8) NULL;
ALTER TABLE orders ADD COLUMN delivery_longitude DECIMAL(11, 8) NULL;

-- Shops/Stores table  
ALTER TABLE shops ADD COLUMN latitude DECIMAL(10, 8) NULL;
ALTER TABLE shops ADD COLUMN longitude DECIMAL(11, 8) NULL;

-- Addresses table
ALTER TABLE addresses ADD COLUMN latitude DECIMAL(10, 8) NULL;
ALTER TABLE addresses ADD COLUMN longitude DECIMAL(11, 8) NULL;
```

## Recommended Backend Fixes

### 1. Fix WalletRepository Type Issues

#### Update WalletRepository
```php
<?php

namespace App\Repositories;

use Illuminate\Http\Request;
use App\Models\Wallet;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class WalletRepository
{
    /**
     * Update wallet by request
     * 
     * @param Request $request
     * @return bool
     */
    public function updateByRequest(Request $request): bool
    {
        try {
            DB::beginTransaction();
            
            $riderId = $request->input('rider_id');
            $orderId = $request->input('order_id');
            $amount = $request->input('amount');
            $type = $request->input('type', 'credit'); // credit or debit
            
            // Validate required fields
            if (!$riderId || !$orderId || !$amount) {
                throw new \InvalidArgumentException('Missing required fields: rider_id, order_id, amount');
            }
            
            // Find or create wallet
            $wallet = Wallet::firstOrCreate(
                ['rider_id' => $riderId],
                ['balance' => 0]
            );
            
            // Update balance based on type
            if ($type === 'credit') {
                $wallet->balance += $amount;
            } else {
                $wallet->balance -= $amount;
                
                // Prevent negative balance
                if ($wallet->balance < 0) {
                    throw new \Exception('Insufficient wallet balance');
                }
            }
            
            $wallet->save();
            
            // Create transaction record
            \App\Models\WalletTransaction::create([
                'rider_id' => $riderId,
                'order_id' => $orderId,
                'amount' => $amount,
                'type' => $type,
                'balance_after' => $wallet->balance,
                'created_at' => now()
            ]);
            
            DB::commit();
            
            Log::info('Wallet updated successfully', [
                'rider_id' => $riderId,
                'order_id' => $orderId,
                'amount' => $amount,
                'type' => $type,
                'new_balance' => $wallet->balance
            ]);
            
            return true;
            
        } catch (\Exception $e) {
            DB::rollBack();
            
            Log::error('Wallet update failed', [
                'rider_id' => $request->input('rider_id'),
                'order_id' => $request->input('order_id'),
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            
            throw $e;
        }
    }
    
    /**
     * Alternative method accepting array data
     * 
     * @param array $data
     * @return bool
     */
    public function updateByArray(array $data): bool
    {
        // Create a mock request object for backward compatibility
        $request = new Request();
        $request->merge($data);
        
        return $this->updateByRequest($request);
    }
}
```

#### Update Controllers
```php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Repositories\WalletRepository;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class OrderController extends Controller
{
    protected $walletRepository;
    
    public function __construct(WalletRepository $walletRepository)
    {
        $this->walletRepository = $walletRepository;
    }
    
    /**
     * Complete order and update rider wallet
     */
    public function completeOrder(Request $request, $orderId): JsonResponse
    {
        try {
            $order = \App\Models\Order::findOrFail($orderId);
            
            // Validate order can be completed
            if ($order->status === 'Delivered') {
                return response()->json([
                    'success' => false,
                    'message' => 'Order already completed'
                ], 400);
            }
            
            // Update order status
            $order->status = 'Delivered';
            $order->delivered_at = now();
            $order->save();
            
            // Update rider wallet - FIXED: Pass Request object
            $walletRequest = new Request([
                'rider_id' => $order->rider_id,
                'order_id' => $order->id,
                'amount' => $order->delivery_fee,
                'type' => 'credit'
            ]);
            
            $this->walletRepository->updateByRequest($walletRequest);
            
            return response()->json([
                'success' => true,
                'message' => 'Order completed successfully',
                'data' => [
                    'order' => $order->load(['shop', 'address']),
                ]
            ]);
            
        } catch (\Exception $e) {
            \Log::error('Order completion failed', [
                'order_id' => $orderId,
                'error' => $e->getMessage()
            ]);
            
            return response()->json([
                'success' => false,
                'message' => 'Failed to complete order. Please try again.'
            ], 500);
        }
    }
}
```

### 2. Enhance Order Details API Response

#### Update OrderDetailsController
```php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use Illuminate\Http\JsonResponse;

class OrderDetailsController extends Controller
{
    /**
     * Get order details with complete GPS coordinates
     */
    public function show($orderId): JsonResponse
    {
        try {
            $order = Order::with([
                'shop' => function($query) {
                    $query->select('id', 'name', 'address', 'phone', 'latitude', 'longitude');
                },
                'address' => function($query) {
                    $query->select('id', 'address', 'latitude', 'longitude', 'phone');
                },
                'rider' => function($query) {
                    $query->select('id', 'name', 'phone');
                }
            ])->findOrFail($orderId);
            
            // Ensure GPS coordinates are present
            $shopCoordinates = $this->getShopCoordinates($order->shop);
            $deliveryCoordinates = $this->getDeliveryCoordinates($order->address);
            
            return response()->json([
                'success' => true,
                'data' => [
                    'order' => [
                        'id' => $order->id,
                        'order_status' => $order->status,
                        'payment_status' => $order->payment_status,
                        'amount' => $order->total_amount,
                        'delivery_fee' => $order->delivery_fee,
                        'created_at' => $order->created_at->toISOString(),
                        
                        // Enhanced shop data with GPS
                        'shop' => [
                            'id' => $order->shop->id,
                            'name' => $order->shop->name,
                            'address' => $order->shop->address,
                            'phone' => $order->shop->phone,
                            'latitude' => $shopCoordinates['latitude'],
                            'longitude' => $shopCoordinates['longitude'],
                        ],
                        
                        // Enhanced delivery address with GPS
                        'address' => [
                            'id' => $order->address->id,
                            'address' => $order->address->address,
                            'phone' => $order->address->phone,
                            'latitude' => $deliveryCoordinates['latitude'],
                            'longitude' => $deliveryCoordinates['longitude'],
                        ],
                        
                        // Add pickup and delivery coordinates for navigation
                        'pickup_coordinates' => [
                            'latitude' => $shopCoordinates['latitude'],
                            'longitude' => $shopCoordinates['longitude'],
                        ],
                        'delivery_coordinates' => [
                            'latitude' => $deliveryCoordinates['latitude'],
                            'longitude' => $deliveryCoordinates['longitude'],
                        ]
                    ]
                ]
            ]);
            
        } catch (\Exception $e) {
            \Log::error('Failed to fetch order details', [
                'order_id' => $orderId,
                'error' => $e->getMessage()
            ]);
            
            return response()->json([
                'success' => false,
                'message' => 'Order not found'
            ], 404);
        }
    }
    
    /**
     * Get shop coordinates with fallback to geocoding
     */
    private function getShopCoordinates($shop): array
    {
        // Return stored coordinates if available
        if ($shop->latitude && $shop->longitude) {
            return [
                'latitude' => (float) $shop->latitude,
                'longitude' => (float) $shop->longitude
            ];
        }
        
        // Fallback: Geocode the address
        $coordinates = $this->geocodeAddress($shop->address);
        
        // Update shop with new coordinates
        $shop->update([
            'latitude' => $coordinates['latitude'],
            'longitude' => $coordinates['longitude']
        ]);
        
        return $coordinates;
    }
    
    /**
     * Get delivery coordinates with fallback to geocoding
     */
    private function getDeliveryCoordinates($address): array
    {
        // Return stored coordinates if available
        if ($address->latitude && $address->longitude) {
            return [
                'latitude' => (float) $address->latitude,
                'longitude' => (float) $address->longitude
            ];
        }
        
        // Fallback: Geocode the address
        $coordinates = $this->geocodeAddress($address->address);
        
        // Update address with new coordinates
        $address->update([
            'latitude' => $coordinates['latitude'],
            'longitude' => $coordinates['longitude']
        ]);
        
        return $coordinates;
    }
    
    /**
     * Geocode address using Google Maps API
     */
    private function geocodeAddress(string $address): array
    {
        try {
            $apiKey = config('services.google.maps_api_key');
            $encodedAddress = urlencode($address);
            $url = "https://maps.googleapis.com/maps/api/geocode/json?address={$encodedAddress}&key={$apiKey}";
            
            $response = file_get_contents($url);
            $data = json_decode($response, true);
            
            if ($data['status'] === 'OK' && !empty($data['results'])) {
                $location = $data['results'][0]['geometry']['location'];
                return [
                    'latitude' => (float) $location['lat'],
                    'longitude' => (float) $location['lng']
                ];
            }
            
            // Fallback coordinates (Dar es Salaam center)
            return [
                'latitude' => -6.7924,
                'longitude' => 39.2083
            ];
            
        } catch (\Exception $e) {
            \Log::error('Geocoding failed', [
                'address' => $address,
                'error' => $e->getMessage()
            ]);
            
            // Fallback coordinates
            return [
                'latitude' => -6.7924,
                'longitude' => 39.2083
            ];
        }
    }
}
```

### 3. Implement Push Notification Backend

#### FCM Token Management
```php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class NotificationController extends Controller
{
    /**
     * Update rider's FCM token
     */
    public function updateFcmToken(Request $request): JsonResponse
    {
        $request->validate([
            'fcm_token' => 'required|string',
            'rider_id' => 'required|exists:riders,id'
        ]);
        
        try {
            $rider = \App\Models\Rider::find($request->rider_id);
            $rider->fcm_token = $request->fcm_token;
            $rider->save();
            
            return response()->json([
                'success' => true,
                'message' => 'FCM token updated successfully'
            ]);
            
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to update FCM token'
            ], 500);
        }
    }
    
    /**
     * Send push notification for new order
     */
    public function sendOrderNotification($orderId): JsonResponse
    {
        try {
            $order = \App\Models\Order::with('rider')->findOrFail($orderId);
            
            if (!$order->rider || !$order->rider->fcm_token) {
                return response()->json([
                    'success' => false,
                    'message' => 'Rider FCM token not found'
                ], 400);
            }
            
            $notification = [
                'title' => 'Mpangilio mpya!',
                'body' => "Umepokea agizo jipya #{$order->id}",
                'data' => [
                    'order_id' => $order->id,
                    'type' => 'new_order',
                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK'
                ]
            ];
            
            $result = $this->sendFcmNotification($order->rider->fcm_token, $notification);
            
            return response()->json([
                'success' => true,
                'message' => 'Notification sent successfully',
                'data' => $result
            ]);
            
        } catch (\Exception $e) {
            \Log::error('Failed to send FCM notification', [
                'order_id' => $orderId,
                'error' => $e->getMessage()
            ]);
            
            return response()->json([
                'success' => false,
                'message' => 'Failed to send notification'
            ], 500);
        }
    }
    
    /**
     * Send FCM notification using HTTP v1 API
     */
    private function sendFcmNotification(string $fcmToken, array $notification): array
    {
        $projectId = config('services.firebase.project_id');
        $accessToken = $this->getAccessToken();
        
        $url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";
        
        $data = [
            'message' => [
                'token' => $fcmToken,
                'notification' => [
                    'title' => $notification['title'],
                    'body' => $notification['body']
                ],
                'data' => $notification['data'],
                'android' => [
                    'notification' => [
                        'channel_id' => 'order_notifications',
                        'sound' => 'default'
                    ]
                ]
            ]
        ];
        
        $headers = [
            'Authorization: Bearer ' . $accessToken,
            'Content-Type: application/json'
        ];
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        return [
            'http_code' => $httpCode,
            'response' => json_decode($response, true)
        ];
    }
    
    /**
     * Get Firebase access token
     */
    private function getAccessToken(): string
    {
        // Implement OAuth2 token retrieval or use Firebase Admin SDK
        // This is a simplified version - use proper authentication in production
        return config('services.firebase.server_key');
    }
}
```

## API Response Standards

### Standard Success Response
```json
{
    "success": true,
    "message": "Operation completed successfully",
    "data": {
        "order": {
            "id": 123,
            "status": "Delivered"
        }
    },
    "timestamp": "2024-12-19T10:30:00Z"
}
```

### Standard Error Response
```json
{
    "success": false,
    "message": "User-friendly error message",
    "error_code": "ORDER_NOT_FOUND",
    "timestamp": "2024-12-19T10:30:00Z",
    "debug": {
        "trace_id": "abc123",
        "details": "Additional debug info for development"
    }
}
```

### Enhanced Order Details Response
```json
{
    "success": true,
    "data": {
        "order": {
            "id": 123,
            "order_status": "Pickup_Confirmed",
            "payment_status": "Pending",
            "amount": 15000,
            "shop": {
                "id": 1,
                "name": "Shop Name",
                "address": "Shop Address",
                "phone": "+255123456789",
                "latitude": -6.7924,
                "longitude": 39.2083
            },
            "address": {
                "id": 1,
                "address": "Delivery Address",
                "phone": "+255123456789",
                "latitude": -6.8024,
                "longitude": 39.2183
            },
            "pickup_coordinates": {
                "latitude": -6.7924,
                "longitude": 39.2083
            },
            "delivery_coordinates": {
                "latitude": -6.8024,
                "longitude": 39.2183
            }
        }
    }
}
```

## Error Handling Best Practices

### 1. Global Exception Handler
```php
<?php

namespace App\Exceptions;

use Illuminate\Foundation\Exceptions\Handler as ExceptionHandler;
use Illuminate\Http\JsonResponse;
use Throwable;

class Handler extends ExceptionHandler
{
    public function render($request, Throwable $exception): JsonResponse
    {
        // API requests should return JSON
        if ($request->expectsJson()) {
            return $this->handleApiException($exception);
        }
        
        return parent::render($request, $exception);
    }
    
    private function handleApiException(Throwable $exception): JsonResponse
    {
        $statusCode = 500;
        $message = 'An error occurred. Please try again.';
        $errorCode = 'INTERNAL_ERROR';
        
        // Handle specific exceptions
        if ($exception instanceof \Illuminate\Database\Eloquent\ModelNotFoundException) {
            $statusCode = 404;
            $message = 'Resource not found';
            $errorCode = 'RESOURCE_NOT_FOUND';
        }
        
        if ($exception instanceof \Illuminate\Validation\ValidationException) {
            $statusCode = 422;
            $message = 'Validation failed';
            $errorCode = 'VALIDATION_ERROR';
        }
        
        // Log the error (but don't expose to client)
        \Log::error('API Exception', [
            'message' => $exception->getMessage(),
            'file' => $exception->getFile(),
            'line' => $exception->getLine(),
            'trace' => $exception->getTraceAsString()
        ]);
        
        $response = [
            'success' => false,
            'message' => $message,
            'error_code' => $errorCode,
            'timestamp' => now()->toISOString()
        ];
        
        // Include debug info only in development
        if (config('app.debug')) {
            $response['debug'] = [
                'exception' => get_class($exception),
                'message' => $exception->getMessage(),
                'file' => $exception->getFile(),
                'line' => $exception->getLine()
            ];
        }
        
        return response()->json($response, $statusCode);
    }
}
```

### 2. Input Validation
```php
<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class OrderStatusUpdateRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'order_id' => 'required|integer|exists:orders,id',
            'status' => 'required|string|in:Pickup_Confirmed,On_The_Way,Delivered',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'delivery_note' => 'nullable|string|max:500'
        ];
    }
    
    public function messages(): array
    {
        return [
            'order_id.required' => 'Order ID is required',
            'order_id.exists' => 'Order not found',
            'status.in' => 'Invalid order status',
            'latitude.between' => 'Invalid latitude value',
            'longitude.between' => 'Invalid longitude value'
        ];
    }
}
```

## Security Considerations

### 1. Authentication Middleware
```php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class AuthenticateRider
{
    public function handle(Request $request, Closure $next)
    {
        $token = $request->bearerToken();
        
        if (!$token) {
            return response()->json([
                'success' => false,
                'message' => 'Authentication token required'
            ], 401);
        }
        
        try {
            $rider = \App\Models\Rider::where('api_token', $token)
                ->where('status', 'active')
                ->first();
                
            if (!$rider) {
                return response()->json([
                    'success' => false,
                    'message' => 'Invalid or expired token'
                ], 401);
            }
            
            $request->attributes->set('rider', $rider);
            
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Authentication failed'
            ], 401);
        }
        
        return $next($request);
    }
}
```

### 2. Rate Limiting
```php
// In RouteServiceProvider or routes/api.php
Route::middleware(['throttle:60,1'])->group(function () {
    // API routes with 60 requests per minute limit
});

Route::middleware(['throttle:10,1'])->group(function () {
    // Sensitive routes with 10 requests per minute limit
    Route::post('/order/{id}/complete', [OrderController::class, 'completeOrder']);
});
```

## Performance Optimization

### 1. Database Indexing
```sql
-- Essential indexes for rider app
CREATE INDEX idx_orders_rider_status ON orders (rider_id, status);
CREATE INDEX idx_orders_created_at ON orders (created_at);
CREATE INDEX idx_wallet_transactions_rider ON wallet_transactions (rider_id, created_at);

-- Spatial indexes for location queries
CREATE SPATIAL INDEX idx_shops_location ON shops (POINT(longitude, latitude));
CREATE SPATIAL INDEX idx_addresses_location ON addresses (POINT(longitude, latitude));
```

### 2. Query Optimization
```php
// ❌ N+1 Query Problem
$orders = Order::all();
foreach ($orders as $order) {
    echo $order->shop->name; // Triggers separate query for each order
}

// ✅ Eager Loading Solution
$orders = Order::with(['shop', 'address', 'rider'])->get();
foreach ($orders as $order) {
    echo $order->shop->name; // No additional queries
}
```

### 3. Caching Strategy
```php
<?php

use Illuminate\Support\Facades\Cache;

class OrderService
{
    public function getRiderOrders($riderId, $status = null)
    {
        $cacheKey = "rider_orders_{$riderId}_{$status}";
        
        return Cache::remember($cacheKey, 300, function () use ($riderId, $status) {
            $query = Order::where('rider_id', $riderId)
                ->with(['shop', 'address']);
                
            if ($status) {
                $query->where('status', $status);
            }
            
            return $query->orderBy('created_at', 'desc')->get();
        });
    }
}
```

## Monitoring & Logging

### 1. Application Logging
```php
<?php

use Illuminate\Support\Facades\Log;

class OrderController extends Controller
{
    public function updateStatus(Request $request, $orderId)
    {
        $startTime = microtime(true);
        
        try {
            Log::info('Order status update started', [
                'order_id' => $orderId,
                'rider_id' => $request->get('rider_id'),
                'new_status' => $request->get('status')
            ]);
            
            // ... business logic ...
            
            $executionTime = (microtime(true) - $startTime) * 1000;
            
            Log::info('Order status update completed', [
                'order_id' => $orderId,
                'execution_time_ms' => $executionTime
            ]);
            
        } catch (\Exception $e) {
            Log::error('Order status update failed', [
                'order_id' => $orderId,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            
            throw $e;
        }
    }
}
```

### 2. Performance Monitoring
```php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class ApiPerformanceMonitor
{
    public function handle(Request $request, Closure $next)
    {
        $startTime = microtime(true);
        $startMemory = memory_get_usage();
        
        $response = $next($request);
        
        $executionTime = (microtime(true) - $startTime) * 1000;
        $memoryUsage = memory_get_usage() - $startMemory;
        
        // Log slow requests
        if ($executionTime > 1000) { // > 1 second
            Log::warning('Slow API request detected', [
                'url' => $request->fullUrl(),
                'method' => $request->method(),
                'execution_time_ms' => $executionTime,
                'memory_usage_bytes' => $memoryUsage,
                'status_code' => $response->getStatusCode()
            ]);
        }
        
        return $response;
    }
}
```

## Deployment Checklist

### Environment Configuration
```bash
# .env file for production
APP_ENV=production
APP_DEBUG=false
APP_URL=https://your-api-domain.com

DB_CONNECTION=mysql
DB_HOST=your-db-host
DB_PORT=3306
DB_DATABASE=total_ride_prod
DB_USERNAME=db_user
DB_PASSWORD=secure_password

CACHE_DRIVER=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis

GOOGLE_MAPS_API_KEY=your_google_maps_key
FIREBASE_PROJECT_ID=your_firebase_project
FIREBASE_SERVER_KEY=your_firebase_server_key

LOG_CHANNEL=daily
LOG_LEVEL=error
```

### Database Migrations
```bash
# Run these commands during deployment
php artisan migrate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan queue:restart
```

### Nginx Configuration
```nginx
server {
    listen 80;
    server_name your-api-domain.com;
    root /var/www/total-ride/public;
    
    index index.php;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    # API rate limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        try_files $uri $uri/ /index.php?$query_string;
    }
}
```

## Conclusion

Implementing these fixes will significantly improve the Total Ride backend:

1. **Error Resolution**: Eliminates wallet repository errors and improves user experience
2. **GPS Accuracy**: Ensures accurate navigation with proper coordinate handling  
3. **Real-time Notifications**: Enables instant order assignments via FCM
4. **Production Readiness**: Comprehensive error handling, logging, and monitoring
5. **Performance**: Optimized queries, caching, and database indexes
6. **Security**: Proper authentication, validation, and rate limiting

### Next Steps
1. Implement wallet repository fixes immediately
2. Add GPS coordinates to database schema and API responses
3. Set up FCM push notification system
4. Deploy monitoring and logging improvements
5. Test all fixes thoroughly in staging environment
6. Gradually roll out to production with monitoring

This documentation should serve as a comprehensive guide for backend developers to resolve current issues and maintain a robust, scalable delivery platform.