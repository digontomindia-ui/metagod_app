# Temple Project API Documentation

This document contains a comprehensive reference of all API endpoints available on the Temple Project backend, using the production base URL: `api.metagod.in`.

---

## Global Base URL
```text
https://api.metagod.in
```

### Table of Contents
1. [Core Services](#1-core-services)
2. [Authentication & Session Management](#2-authentication--session-management)
3. [User & Profile Management](#3-user--profile-management)
4. [Temples & Content](#4-temples--content)
5. [Vendors Management](#5-vendors-management)
6. [Products Commerce](#6-products-commerce)
7. [Orders & Shipments](#7-orders--shipments)
8. [Admin Operations](#8-admin-operations)
9. [Notifications System](#9-notifications-system)
10. [Pages CMS](#10-pages-cms)
11. [Categories Management](#11-categories-management)
12. [Pujas Management](#12-pujas-management)
13. [Prasad Management](#13-prasad-management)
14. [Donations & Offerings](#14-donations--offerings)
15. [Subscriptions System](#15-subscriptions-system)
16. [Puja Orders System](#16-puja-orders-system)
17. [Wallet System](#17-wallet-system)
18. [Razorpay Integrations](#18-razorpay-integrations)
19. [Spiritual Activities Tracker](#19-spiritual-activities-tracker)
20. [Addresses Management](#20-addresses-management)
21. [Experts Registry](#21-experts-registry)
22. [Platform Settings CMS](#22-platform-settings-cms)
23. [Hero Slides CMS](#23-hero-slides-cms)
24. [VR Experiences Management](#24-vr-experiences-management)
25. [Consultations & Expert Live Chat](#25-consultations--expert-live-chat)
26. [AI Chat & Sanctuary Oracle Proxy](#26-ai-chat--sanctuary-oracle-proxy)
27. [Image Upload Service](#27-image-upload-service)
28. [Integrations Webhooks](#28-integrations-webhooks)
29. [Bookings Module (Inactive)](#29-bookings-module-inactive)

---

## 1. Core Services

### Health Check
* **Endpoint:** `GET https://api.metagod.in/health`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Service is healthy"
}
```

### Home Status Check
* **Endpoint:** `GET https://api.metagod.in/`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Temple backend is running"
}
```

---

## 2. Authentication & Session Management
**Base Path:** `/api/auth`

### Send OTP
* **Endpoint:** `POST https://api.metagod.in/api/auth/send-otp`
* **Access:** Public
* **Request Body:**
```json
{
  "phone": "9999988888",
  "email": "devotee@example.com"
}
```
> Note: Either `phone` or `email` must be provided. Rate limited to max 3 OTP requests per 5 minutes per identifier.
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "OTP sent successfully to 9999988888"
}
```

### Verify OTP
* **Endpoint:** `POST https://api.metagod.in/api/auth/verify-otp`
* **Access:** Public
* **Request Body:**
```json
{
  "phone": "9999988888",
  "email": "devotee@example.com",
  "otp": "123456"
}
```
* **Response (200 OK - User Exists / Login Success):**
```json
{
  "success": true,
  "user_exists": true,
  "message": "Login successful",
  "accessToken": "eyJhbGciOiJIUzI1NiIsIn...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsIn...",
  "tokens": {
    "accessToken": "...",
    "refreshToken": "..."
  },
  "user": {
    "id": "60c72b2f9b1d8e12345678ab",
    "name": "Devotee One",
    "email": "devotee@example.com",
    "role": "USER"
  }
}
```
* **Response (200 OK - User Does Not Exist / Ready for Signup):**
```json
{
  "success": true,
  "user_exists": false,
  "message": "OTP verified. No account found with this identifier. Please complete registration.",
  "identifier": "9999988888"
}
```

### Register User
* **Endpoint:** `POST https://api.metagod.in/api/auth/register`
* **Access:** Public
* **Request Body:**
```json
{
  "name": "Rahul",
  "email": "rahul@example.com",
  "password": "password123",
  "role": "USER" 
}
```
* **Response (201 Created):**
```json
{
  "success": true,
  "message": "User registered successfully",
  "user": {
    "id": "60c72b2f9b1d8e12345678cd",
    "name": "Rahul",
    "email": "rahul@example.com",
    "role": "USER"
  }
}
```

### Register Vendor Application
* **Endpoint:** `POST https://api.metagod.in/api/auth/register-vendor`
* **Access:** Public
* **Request Body:**
```json
{
  "shopName": "Krishna Flora & Prasad",
  "ownerName": "Gopal Das",
  "email": "gopal@example.com",
  "phone": "9876543210",
  "address": "Vrindavan Path, UP",
  "password": "securepassword123"
}
```
* **Response (201 Created):**
```json
{
  "success": true,
  "message": "Vendor application submitted",
  "data": {
    "_id": "651d87e07a685f0012345678",
    "userId": "651d87e07a685f0012345679",
    "shopName": "Krishna Flora & Prasad",
    "phone": "9876543210",
    "address": "Vrindavan Path, UP",
    "approved": false,
    "createdAt": "2026-06-01T22:30:00.000Z"
  }
}
```

### Login
* **Endpoint:** `POST https://api.metagod.in/api/auth/login`
* **Access:** Public
* **Request Body:**
```json
{
  "email": "rahul@example.com",
  "password": "password123"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "accessToken": "eyJhbGciOi...",
  "refreshToken": "eyJhbGciOi...",
  "tokens": {
    "accessToken": "...",
    "refreshToken": "..."
  },
  "user": {
    "id": "60c72b2f9b1d8e12345678cd",
    "name": "Rahul",
    "email": "rahul@example.com",
    "role": "USER"
  }
}
```

### Get Authenticated User Details (Me)
* **Endpoint:** `GET https://api.metagod.in/api/auth/me`
* **Access:** Authenticated (Bearer Token required)
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "user": {
    "id": "60c72b2f9b1d8e12345678cd",
    "name": "Rahul",
    "email": "rahul@example.com",
    "role": "USER",
    "permissions": [],
    "activeSessions": [
      {
        "sid": "17364b6e-1d6f-47dc-8208-e8cb9b87df34",
        "deviceInfo": "Chrome on Windows",
        "lastActive": "2026-06-01T22:30:00.000Z"
      }
    ]
  }
}
```

### Logout
* **Endpoint:** `POST https://api.metagod.in/api/auth/logout`
* **Access:** Authenticated (Bearer Token required)
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "refreshToken": "eyJhbGciOi..."
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Logged out"
}
```

### Refresh Access Tokens
* **Endpoint:** `POST https://api.metagod.in/api/auth/refresh`
* **Access:** Public
* **Request Body:**
```json
{
  "refreshToken": "eyJhbGciOi..."
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "accessToken": "eyJhbGciOi...",
  "refreshToken": "eyJhbGciOi...",
  "tokens": {
    "accessToken": "...",
    "refreshToken": "..."
  },
  "user": {
    "id": "60c72b2f9b1d8e12345678cd",
    "name": "Rahul",
    "role": "USER"
  }
}
```

### Change Password
* **Endpoint:** `POST https://api.metagod.in/api/auth/change-password`
* **Access:** Authenticated (Bearer Token required)
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "currentPassword": "oldpassword123",
  "newPassword": "newpassword123"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Password changed successfully"
}
```

### Update Password (Direct Set)
* **Endpoint:** `PUT https://api.metagod.in/api/auth/update-password`
* **Access:** Authenticated (Bearer Token required)
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "password": "brandnewpassword123"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Password updated successfully"
}
```

### Terminate Active Session
* **Endpoint:** `DELETE https://api.metagod.in/api/auth/sessions/:sid`
* **Access:** Authenticated (Bearer Token required)
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Session terminated successfully."
}
```

---

## 3. User & Profile Management
**Base Path:** `/api/users`

### Get User Profile
* **Endpoint:** `GET https://api.metagod.in/api/users/profile`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "60c72b2f9b1d8e12345678cd",
    "name": "Rahul Sharma",
    "email": "rahul@example.com",
    "role": "USER",
    "walletBalance": 1500,
    "profileImage": "https://res.cloudinary.com/..."
  }
}
```

### Update User Profile
* **Endpoint:** `PUT https://api.metagod.in/api/users/profile`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "name": "Rahul Sharma",
  "profileImage": "https://res.cloudinary.com/..."
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "60c72b2f9b1d8e12345678cd",
    "name": "Rahul Sharma",
    "profileImage": "https://res.cloudinary.com/..."
  }
}
```

### Get My Purchased Gifts History
* **Endpoint:** `GET https://api.metagod.in/api/users/gifts`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "653b87b12abc0012345678de",
      "productId": {
        "_id": "651d87e07a685f00123456aa",
        "name": "Sandalwood Incense Stick Box",
        "price": 150
      },
      "type": "GIFT",
      "status": "DELIVERED",
      "createdAt": "2026-05-30T10:15:00.000Z"
    }
  ]
}
```

### Get All Users
* **Endpoint:** `GET https://api.metagod.in/api/users/all`
* **Access:** Admin/Super Admin only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "60c72b2f9b1d8e12345678cd",
      "name": "Rahul",
      "email": "rahul@example.com",
      "role": "USER",
      "isActive": true
    }
  ]
}
```

### Update User Role
* **Endpoint:** `PUT https://api.metagod.in/api/users/role`
* **Access:** Admin/Super Admin only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "id": "60c72b2f9b1d8e12345678cd",
  "role": "VENDOR"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "User role updated successfully",
  "data": {
    "_id": "60c72b2f9b1d8e12345678cd",
    "role": "VENDOR"
  }
}
```

### Get Customer Profile & Order Summary
* **Endpoint:** `GET https://api.metagod.in/api/users/admin/customers/:userId/summary`
* **Access:** Admin/Super Admin only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "totalSpent": 3500,
    "orderCount": 4,
    "completedOrders": 3,
    "cancelledOrders": 1,
    "customer": {
      "_id": "60c72b2f9b1d8e12345678cd",
      "name": "Rahul",
      "email": "rahul@example.com"
    }
  }
}
```

---

## 4. Temples & Content
**Base Path:** `/api/temples`

### List All Temples
* **Endpoint:** `GET https://api.metagod.in/api/temples`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "651d87e07a685f00123456e0",
      "name": "Kashi Vishwanath Temple",
      "location": "Varanasi, UP",
      "coverImage": "https://example.com/kashi.jpg",
      "isLive": true
    }
  ]
}
```

### List Temples Live Right Now
* **Endpoint:** `GET https://api.metagod.in/api/temples/live-now`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "651d87e07a685f00123456e0",
      "name": "Kashi Vishwanath Temple",
      "liveStreamUrl": "https://youtube.com/live/kashi",
      "isLive": true
    }
  ]
}
```

### Get Temple Details By ID
* **Endpoint:** `GET https://api.metagod.in/api/temples/:id`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "651d87e07a685f00123456e0",
    "name": "Kashi Vishwanath Temple",
    "location": "Varanasi, UP",
    "description": "One of the most famous Hindu temples dedicated to Lord Shiva.",
    "coverImage": "https://example.com/kashi.jpg",
    "posterImage": "https://example.com/kashi-poster.jpg",
    "liveStreamUrl": "https://youtube.com/live/kashi",
    "isLive": true
  }
}
```

### Get Temple Live Stream Info
* **Endpoint:** `GET https://api.metagod.in/api/temples/:id/live`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "isLive": true,
    "liveStreamUrl": "https://youtube.com/live/kashi",
    "rtmpUrl": "rtmp://api.metagod.in/live",
    "streamKey": "live_651d87e07a685f00123456e0"
  }
}
```

### Get Temple Contents (Feeds/Aarti events)
* **Endpoint:** `GET https://api.metagod.in/api/temples/:id/contents`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "652c77a10fdc110012345678",
      "templeId": "651d87e07a685f00123456e0",
      "type": "event",
      "title": "Mangala Aarti",
      "mediaUrl": "https://example.com/aarti.mp4"
    }
  ]
}
```

### Get Temple Gift History
* **Endpoint:** `GET https://api.metagod.in/api/temples/:id/gifts`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "653b87b12abc0012345678de",
      "userId": "60c72b2f9b1d8e12345678cd",
      "productId": {
        "name": "Premium Flower Garland",
        "price": 300
      },
      "type": "GIFT",
      "createdAt": "2026-06-01T20:00:00Z"
    }
  ]
}
```

### Get Temple Products
* **Endpoint:** `GET https://api.metagod.in/api/temples/:id/products`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "651d87e07a685f00123456aa",
      "templeId": "651d87e07a685f00123456e0",
      "name": "Sandalwood Incense Stick Box",
      "price": 150,
      "image": "https://example.com/incense.jpg",
      "stock": 50
    }
  ]
}
```

### Create Temple
* **Endpoint:** `POST https://api.metagod.in/api/temples`
* **Access:** Vendor / Admin / Super Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "name": "Kedarnath Temple",
  "location": "Uttarakhand",
  "description": "Ancient Shiva Temple in Himalayas",
  "coverImage": "https://example.com/kedar-cover.jpg",
  "posterImage": "https://example.com/kedar-poster.jpg",
  "liveStreamUrl": "https://youtube.com/live/kedar",
  "streamKey": "stream_key_custom",
  "rtmpUrl": "rtmp://custom.url",
  "vrVideoUrl": "https://example.com/kedar-vr.mp4",
  "isLive": true
}
```
* **Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "_id": "651d87e07a685f00123456ff",
    "name": "Kedarnath Temple",
    "location": "Uttarakhand",
    "isLive": true
  }
}
```

### Update Temple Details
* **Endpoint:** `PUT https://api.metagod.in/api/temples/:id`
* **Access:** Vendor / Admin / Super Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:** (All fields optional)
```json
{
  "name": "Kedarnath Temple (Main Shrine)",
  "isLive": false
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "651d87e07a685f00123456ff",
    "name": "Kedarnath Temple (Main Shrine)",
    "isLive": false
  }
}
```

### Delete Temple
* **Endpoint:** `DELETE https://api.metagod.in/api/temples/:id`
* **Access:** Vendor / Admin / Super Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Temple deleted successfully"
}
```

---

## 5. Vendors Management
**Base Path:** `/api/vendors`

### Apply to Become Vendor
* **Endpoint:** `POST https://api.metagod.in/api/vendors/apply`
* **Access:** User / Vendor
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "temples": ["651d87e07a685f00123456e0"]
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Vendor application submitted successfully",
  "data": {
    "userId": "60c72b2f9b1d8e12345678cd",
    "temples": ["651d87e07a685f00123456e0"],
    "approved": false
  }
}
```

### Get Logged In Vendor Profile (Me)
* **Endpoint:** `GET https://api.metagod.in/api/vendors/me`
* **Access:** Vendor / Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "651d87e07a685f0012345678",
    "shopName": "Krishna Flora & Prasad",
    "approved": true,
    "temples": ["651d87e07a685f00123456e0"]
  }
}
```

### Get Vendor Assigned Temples
* **Endpoint:** `GET https://api.metagod.in/api/vendors/temples`
* **Access:** Vendor / Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "651d87e07a685f00123456e0",
      "name": "Kashi Vishwanath Temple",
      "location": "Varanasi, UP"
    }
  ]
}
```

### Get Vendor Owned Products
* **Endpoint:** `GET https://api.metagod.in/api/vendors/products`
* **Access:** Vendor / Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "651d87e07a685f00123456aa",
      "name": "Sandalwood Incense Stick Box",
      "price": 150,
      "stock": 50
    }
  ]
}
```

---

## 6. Products Commerce
**Base Path:** `/api/products` (Some paths base `/api` but routed globally)

### List Global Products
* **Endpoint:** `GET https://api.metagod.in/api/products`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "651d87e07a685f00123456aa",
      "name": "Sandalwood Incense Stick Box",
      "price": 150,
      "category": "ESSENTIALS",
      "image": "https://example.com/incense.jpg",
      "stock": 50
    }
  ]
}
```

### Create Vendor Product
* **Endpoint:** `POST https://api.metagod.in/api/products/vendors/products`
* **Access:** Vendor / Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "templeId": "651d87e07a685f00123456e0",
  "name": "Sandalwood Incense Stick Box",
  "price": 150,
  "category": "ESSENTIALS",
  "image": "https://example.com/incense.jpg",
  "stock": 50
}
```
* **Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "_id": "651d87e07a685f00123456aa",
    "name": "Sandalwood Incense Stick Box",
    "price": 150,
    "stock": 50
  }
}
```

### Get My Vendor Products (Duplicate Shortcut)
* **Endpoint:** `GET https://api.metagod.in/api/products/vendors/products`
* **Access:** Vendor / Admin
* **Headers:** `Authorization: Bearer <accessToken>`

### Get Vendor Product Details By ID
* **Endpoint:** `GET https://api.metagod.in/api/products/vendors/products/:id`
* **Access:** Vendor / Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "651d87e07a685f00123456aa",
    "name": "Sandalwood Incense Stick Box",
    "price": 150,
    "stock": 50
  }
}
```

### Update Vendor Product
* **Endpoint:** `PUT https://api.metagod.in/api/products/vendors/products/:id`
* **Access:** Vendor / Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "name": "Premium Sandalwood Incense Stick Box",
  "price": 180,
  "stock": 40
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "651d87e07a685f00123456aa",
    "name": "Premium Sandalwood Incense Stick Box",
    "price": 180,
    "stock": 40
  }
}
```

### Delete Vendor Product
* **Endpoint:** `DELETE https://api.metagod.in/api/products/vendors/products/:id`
* **Access:** Vendor / Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Product deleted successfully"
}
```

---

## 7. Orders & Shipments
**Base Path:** `/api/orders`

### Create Order (Self or Gift)
* **Endpoint:** `POST https://api.metagod.in/api/orders`
* **Access:** User / Vendor / Admin (under maintenance guard)
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "productId": "651d87e07a685f00123456aa",
  "type": "GIFT" 
}
```
> Note: Type can be `SELF` (for personal home delivery) or `GIFT` (which displays immediately in the live temple streams/feeds).
* **Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "_id": "653b87b12abc0012345678de",
    "userId": "60c72b2f9b1d8e12345678cd",
    "productId": "651d87e07a685f00123456aa",
    "price": 150,
    "type": "GIFT",
    "status": "PENDING"
  }
}
```

### Get My Personal Orders
* **Endpoint:** `GET https://api.metagod.in/api/orders/my`
* **Access:** User / Vendor / Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "653b87b12abc0012345678de",
      "productId": {
        "name": "Sandalwood Incense Stick Box",
        "price": 150
      },
      "type": "GIFT",
      "status": "PENDING"
    }
  ]
}
```

### Get My Personal Gift Orders
* **Endpoint:** `GET https://api.metagod.in/api/orders/my/gifts`
* **Access:** User / Vendor / Admin
* **Headers:** `Authorization: Bearer <accessToken>`

### Get Vendor Incoming Orders List
* **Endpoint:** `GET https://api.metagod.in/api/orders/vendor`
* **Access:** Vendor Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "653b87b12abc0012345678de",
      "productId": {
        "name": "Sandalwood Incense Stick Box"
      },
      "price": 150,
      "status": "PENDING"
    }
  ]
}
```

### Get Vendor Order Detail By ID
* **Endpoint:** `GET https://api.metagod.in/api/orders/vendor/:id`
* **Access:** Vendor Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Update Vendor Order Status
* **Endpoint:** `PUT https://api.metagod.in/api/orders/vendor/:id/status`
* **Access:** Vendor Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "status": "DELIVERED"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "653b87b12abc0012345678de",
    "status": "DELIVERED"
  }
}
```

### Admin: Create Courier Shipment (Shiprocket)
* **Endpoint:** `POST https://api.metagod.in/api/orders/:id/create-shipment`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Shipment created successfully on Shiprocket",
  "shipmentId": 12345678
}
```

### Admin: Generate AWB Waybill (Shiprocket)
* **Endpoint:** `POST https://api.metagod.in/api/orders/:id/generate-awb`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "AWB generated successfully",
  "awbCode": "SR1234567890"
}
```

### Get Order Detail By ID
* **Endpoint:** `GET https://api.metagod.in/api/orders/:id`
* **Access:** User / Vendor / Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "653b87b12abc0012345678de",
    "productId": {
      "name": "Sandalwood Incense Stick Box",
      "price": 150
    },
    "status": "DELIVERED"
  }
}
```

### Cancel My Order
* **Endpoint:** `PUT https://api.metagod.in/api/orders/:id/cancel`
* **Access:** User / Vendor / Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Order cancelled successfully"
}
```

---

## 8. Admin Operations
**Base Path:** `/api/admin`

### Get Dashboard Statistics Summary
* **Endpoint:** `GET https://api.metagod.in/api/admin/summary`
* **Access:** Admin / Vendor
* **Headers:** `Authorization: Bearer <accessToken>`

### List All Orders In Platform
* **Endpoint:** `GET https://api.metagod.in/api/admin/orders`
* **Access:** Admin / Vendor
* **Headers:** `Authorization: Bearer <accessToken>`

### Admin Create Temple Shortcut
* **Endpoint:** `POST https://api.metagod.in/api/admin/temples`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Admin List Temples
* **Endpoint:** `GET https://api.metagod.in/api/admin/temples`
* **Access:** Admin / Vendor
* **Headers:** `Authorization: Bearer <accessToken>`

### Admin Update Temple Details
* **Endpoint:** `PUT https://api.metagod.in/api/admin/temples/:id`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Admin Delete Temple
* **Endpoint:** `DELETE https://api.metagod.in/api/admin/temples/:id`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Add Temple Feed Content (Aarti Video/Image/Event Info)
* **Endpoint:** `POST https://api.metagod.in/api/admin/temples/:id/contents`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "type": "event",
  "title": "Evening Aarti",
  "mediaUrl": "https://example.com/evening_aarti.mp4"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "templeId": "651d87e07a685f00123456e0",
    "type": "event",
    "title": "Evening Aarti",
    "mediaUrl": "https://example.com/evening_aarti.mp4"
  }
}
```

### Admin Create Vendor Profile
* **Endpoint:** `POST https://api.metagod.in/api/admin/vendors`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### List All Vendors
* **Endpoint:** `GET https://api.metagod.in/api/admin/vendors`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Get Vendor Profile By ID
* **Endpoint:** `GET https://api.metagod.in/api/admin/vendors/:id`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Delete Vendor Profile
* **Endpoint:** `DELETE https://api.metagod.in/api/admin/vendors/:id`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Approve Vendor Application
* **Endpoint:** `PUT https://api.metagod.in/api/admin/vendors/:id/approve`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Vendor approved successfully"
}
```

### Update Vendor Details (Assign Temples/Config modules)
* **Endpoint:** `PUT https://api.metagod.in/api/admin/vendors/:id`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### List Vendor Categories
* **Endpoint:** `GET https://api.metagod.in/api/admin/vendor-categories`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Create Vendor Category
* **Endpoint:** `POST https://api.metagod.in/api/admin/vendor-categories`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Create Product
* **Endpoint:** `POST https://api.metagod.in/api/admin/products`
* **Access:** Admin / Vendor
* **Headers:** `Authorization: Bearer <accessToken>`

### List All Products (Admin)
* **Endpoint:** `GET https://api.metagod.in/api/admin/products`
* **Access:** Admin / Vendor
* **Headers:** `Authorization: Bearer <accessToken>`

### Update Product details (Admin)
* **Endpoint:** `PUT https://api.metagod.in/api/admin/products/:id`
* **Access:** Admin / Vendor
* **Headers:** `Authorization: Bearer <accessToken>`

### Delete Product (Admin)
* **Endpoint:** `DELETE https://api.metagod.in/api/admin/products/:id`
* **Access:** Admin / Vendor
* **Headers:** `Authorization: Bearer <accessToken>`

### Create Category
* **Endpoint:** `POST https://api.metagod.in/api/admin/categories`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### List Categories (Admin)
* **Endpoint:** `GET https://api.metagod.in/api/admin/categories`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Update Category (Admin)
* **Endpoint:** `PUT https://api.metagod.in/api/admin/categories/:id`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Delete Category (Admin)
* **Endpoint:** `DELETE https://api.metagod.in/api/admin/categories/:id`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Get Order Detail (Admin)
* **Endpoint:** `GET https://api.metagod.in/api/admin/orders/:id`
* **Access:** Admin / Vendor
* **Headers:** `Authorization: Bearer <accessToken>`

### Update Order Status (Admin)
* **Endpoint:** `PUT https://api.metagod.in/api/admin/orders/:id/status`
* **Access:** Admin / Vendor
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "status": "DELIVERED" 
}
```
> Enums allowed: `PENDING`, `DELIVERED`, `CANCELLED`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "653b87b12abc0012345678de",
    "status": "DELIVERED"
  }
}
```

### Moderate Live Room: Pin Chat Message
* **Endpoint:** `PUT https://api.metagod.in/api/admin/temples/:templeId/chat/messages/:messageId/pin`
* **Access:** Admin / Moderation
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Message pinned successfully"
}
```

### Moderate Live Room: Delete Chat Message
* **Endpoint:** `DELETE https://api.metagod.in/api/admin/temples/:templeId/chat/messages/:messageId`
* **Access:** Admin / Moderation
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Message deleted successfully"
}
```

### Get Analytical Trends (Revenue/Gifts/Active sessions)
* **Endpoint:** `GET https://api.metagod.in/api/admin/analytics`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Query Parameters:** (Optional)
  * `startDate` (ISO Date string, e.g. `2026-03-01T00:00:00.000Z`)
  * `endDate` (ISO Date string, e.g. `2026-03-31T23:59:59.999Z`)
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "giftsPerTemple": [],
    "topVendors": [],
    "giftTrends": [],
    "liveSessionTrends": [],
    "activeLiveSessions": 5,
    "notificationSummary": {},
    "filters": {
      "startDate": "2026-03-01T00:00:00.000Z",
      "endDate": "2026-03-31T23:59:59.999Z"
    }
  }
}
```

### List Users Registry (Admin)
* **Endpoint:** `GET https://api.metagod.in/api/admin/users`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Get User Details (Admin)
* **Endpoint:** `GET https://api.metagod.in/api/admin/users/:id`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Suspend User (Block Login)
* **Endpoint:** `PUT https://api.metagod.in/api/admin/users/:id/suspend`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "User suspended successfully"
}
```

### Activate/Restore Suspended User
* **Endpoint:** `PUT https://api.metagod.in/api/admin/users/:id/activate`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "User activated successfully"
}
```

### Update User Role (Admin Command)
* **Endpoint:** `PUT https://api.metagod.in/api/admin/users/:id/role`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "role": "ADMIN"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "User role updated successfully"
}
```

---

## 9. Notifications System
**Base Path:** `/api/notifications`

### Get My Notifications
* **Endpoint:** `GET https://api.metagod.in/api/notifications`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "654c77a10fdc110012345679",
      "userId": "60c72b2f9b1d8e12345678cd",
      "title": "Order Placed Successfully",
      "message": "Your gift order for Sandalwood Incense Stick Box is placed.",
      "read": false,
      "createdAt": "2026-06-01T21:00:00Z"
    }
  ]
}
```

### Get Unread Notifications Count
* **Endpoint:** `GET https://api.metagod.in/api/notifications/unread/count`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "unreadCount": 1
}
```

### Mark All Notifications As Read
* **Endpoint:** `PUT https://api.metagod.in/api/notifications/read-all`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "All notifications marked as read"
}
```

### Mark Single Notification As Read
* **Endpoint:** `PUT https://api.metagod.in/api/notifications/:id/read`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Notification marked as read"
}
```

### Delete Notification Record
* **Endpoint:** `DELETE https://api.metagod.in/api/notifications/:id`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Notification deleted successfully"
}
```

### Admin: Notification Delivery Pipeline Analytics
* **Endpoint:** `GET https://api.metagod.in/api/notifications/analytics`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Admin: Send Broadcast Notification
* **Endpoint:** `POST https://api.metagod.in/api/notifications/broadcast`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "title": "Divine Festival Celebration",
  "message": "Join us tomorrow for the grand Aarti stream live!"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Broadcast sent to all users"
}
```

### Admin: List Broadcasts History
* **Endpoint:** `GET https://api.metagod.in/api/notifications/broadcasts`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

---

## 10. Pages CMS
**Base Path:** `/api/pages`

### Get All Static Pages
* **Endpoint:** `GET https://api.metagod.in/api/pages`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "slug": "terms-of-service",
      "title": "Terms of Service",
      "content": "Sacred terms of usage...",
      "isVisibleInFooter": true
    }
  ]
}
```

### Get Static Page Content By Slug
* **Endpoint:** `GET https://api.metagod.in/api/pages/:slug`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "slug": "terms-of-service",
    "title": "Terms of Service",
    "content": "Sacred terms of usage...",
    "isVisibleInFooter": true
  }
}
```

### Update/Create Page (CMS)
* **Endpoint:** `PUT https://api.metagod.in/api/pages/:slug`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "title": "Updated Terms of Service",
  "content": "New updated terms of usage...",
  "isVisibleInFooter": true
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "slug": "terms-of-service",
    "title": "Updated Terms of Service",
    "content": "New updated terms of usage...",
    "isVisibleInFooter": true
  }
}
```

### Delete Page (CMS)
* **Endpoint:** `DELETE https://api.metagod.in/api/pages/:slug`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Page deleted successfully"
}
```

---

## 11. Categories Management
**Base Path:** `/api/categories`

### List Categories
* **Endpoint:** `GET https://api.metagod.in/api/categories`
* **Access:** Public
* **Query Parameters:** (Optional)
  * `type` (Filter by category type. Enums allowed: `PRODUCT`, `PUJAS`, `PUNDITS`, `ASTROLOGY`, `SERVICE`, `TEMPLE`, `ALL`)
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "651d87e07a685f00123456bb",
      "name": "12 Jyotirlingas",
      "filterKey": "jyotirlingas",
      "image": "https://example.com/jyotir.jpg",
      "description": "Premium Jyotirlinga shrines selection",
      "type": "TEMPLE",
      "temples": []
    }
  ]
}
```

### Create Category
* **Endpoint:** `POST https://api.metagod.in/api/categories`
* **Access:** Public (Should restrict to Admin/Vendor depending on setup)
* **Request Body:**
```json
{
  "name": "12 Jyotirlingas",
  "filterKey": "jyotirlingas",
  "image": "https://example.com/jyotir.jpg",
  "description": "Premium Jyotirlinga shrines selection",
  "type": "TEMPLE",
  "temples": ["651d87e07a685f00123456e0"]
}
```
* **Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "_id": "651d87e07a685f00123456bb",
    "name": "12 Jyotirlingas"
  }
}
```

### Update Category Details
* **Endpoint:** `PUT https://api.metagod.in/api/categories/:id`
* **Access:** Public (Requires Admin in production workflow)
* **Request Body:** (All fields optional)
```json
{
  "name": "Sacred 12 Jyotirlingas"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "651d87e07a685f00123456bb",
    "name": "Sacred 12 Jyotirlingas"
  }
}
```

### Delete Category
* **Endpoint:** `DELETE https://api.metagod.in/api/categories/:id`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Category deleted successfully"
}
```

---

## 12. Pujas Management
**Base Path:** `/api/pujas`

### List Available Pujas
* **Endpoint:** `GET https://api.metagod.in/api/pujas`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "652c77a10fdc110012345690",
      "templeId": "651d87e07a685f00123456e0",
      "name": "Maha Mrityunjaya Puja",
      "price": 1500,
      "duration": "45 Mins",
      "benefits": "Good health, victory, longevity",
      "image": "https://example.com/puja.jpg",
      "vendorId": "651d87e07a685f0012345678"
    }
  ]
}
```

### Create Sacred Puja Offering
* **Endpoint:** `POST https://api.metagod.in/api/pujas`
* **Access:** Vendor / Admin / Super Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "templeId": "651d87e07a685f00123456e0",
  "name": "Maha Mrityunjaya Puja",
  "price": 1500,
  "duration": "45 Mins",
  "benefits": "Good health, victory, longevity",
  "image": "https://example.com/puja.jpg",
  "vendorId": "651d87e07a685f0012345678"
}
```
* **Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "_id": "652c77a10fdc110012345690",
    "name": "Maha Mrityunjaya Puja"
  }
}
```

### Update Puja Details
* **Endpoint:** `PUT https://api.metagod.in/api/pujas/:id`
* **Access:** Vendor / Admin / Super Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:** (All fields optional)
```json
{
  "price": 1800
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "652c77a10fdc110012345690",
    "price": 1800
  }
}
```

### Delete Puja
* **Endpoint:** `DELETE https://api.metagod.in/api/pujas/:id`
* **Access:** Vendor / Admin / Super Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Puja deleted successfully"
}
```

---

## 13. Prasad Management
**Base Path:** `/api/prasad`

### List Prasad Items
* **Endpoint:** `GET https://api.metagod.in/api/prasad`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "652c77a10fdc110012345699",
      "templeId": "651d87e07a685f00123456e0",
      "name": "Laddoo Prasad Box",
      "price": 250,
      "weight": "500g",
      "category": "Sweets",
      "image": "https://example.com/laddu.jpg",
      "vendorId": "651d87e07a685f0012345678"
    }
  ]
}
```

### Create Prasad Item
* **Endpoint:** `POST https://api.metagod.in/api/prasad`
* **Access:** Vendor / Admin / Super Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "templeId": "651d87e07a685f00123456e0",
  "name": "Laddoo Prasad Box",
  "price": 250,
  "weight": "500g",
  "category": "Sweets",
  "image": "https://example.com/laddu.jpg",
  "vendorId": "651d87e07a685f0012345678"
}
```
* **Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "_id": "652c77a10fdc110012345699",
    "name": "Laddoo Prasad Box"
  }
}
```

### Update Prasad Details
* **Endpoint:** `PUT https://api.metagod.in/api/prasad/:id`
* **Access:** Vendor / Admin / Super Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:** (All fields optional)
```json
{
  "price": 300
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "652c77a10fdc110012345699",
    "price": 300
  }
}
```

### Delete Prasad Item
* **Endpoint:** `DELETE https://api.metagod.in/api/prasad/:id`
* **Access:** Vendor / Admin / Super Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Prasad deleted successfully"
}
```

---

## 14. Donations & Offerings
**Base Path:** `/api/donations`

### Create Razorpay Donation Order
* **Endpoint:** `POST https://api.metagod.in/api/donations/create-order`
* **Access:** Public (Protected under maintenance guard)
* **Request Body:**
```json
{
  "amount": 501
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "order_DONATE123456",
    "entity": "order",
    "amount": 50100,
    "currency": "INR",
    "receipt": "receipt_17364b6e..."
  }
}
```

### Verify Donation Payment & Record
* **Endpoint:** `POST https://api.metagod.in/api/donations/verify-payment`
* **Access:** Public (Protected under maintenance guard)
* **Request Body:**
```json
{
  "razorpay_order_id": "order_DONATE123456",
  "razorpay_payment_id": "pay_DONATE654321",
  "razorpay_signature": "signature_hash_value...",
  "donationData": {
    "userId": "60c72b2f9b1d8e12345678cd",
    "templeId": "651d87e07a685f00123456e0",
    "amount": 501,
    "donorName": "Rahul Sharma",
    "donorEmail": "rahul@example.com",
    "donorPhone": "9999988888",
    "offeringName": "Temple Construction Fund"
  }
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Payment successful",
  "data": {
    "_id": "653b87b12abc0012345678ee",
    "donorName": "Rahul Sharma",
    "amount": 501,
    "status": "completed"
  }
}
```

### Save Mock Donation (Non-Razorpay flow for testing)
* **Endpoint:** `POST https://api.metagod.in/api/donations/mock-save`
* **Access:** Public (Protected under maintenance guard)
* **Request Body:**
```json
{
  "userId": "60c72b2f9b1d8e12345678cd",
  "templeId": "651d87e07a685f00123456e0",
  "amount": 501,
  "donorName": "Rahul Sharma",
  "donorEmail": "rahul@example.com",
  "donorPhone": "9999988888",
  "offeringName": "Temple Construction Fund"
}
```
* **Response (201 Created):**
```json
{
  "success": true,
  "message": "Sacred offering recorded!",
  "data": {
    "_id": "653b87b12abc0012345678ff",
    "donorName": "Rahul Sharma",
    "amount": 501,
    "razorpayPaymentId": "MOCK_PAY_ABCD12",
    "status": "completed"
  }
}
```

### List All Platform Donations
* **Endpoint:** `GET https://api.metagod.in/api/donations`
* **Access:** Admin / Super Admin
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "653b87b12abc0012345678ee",
      "amount": 501,
      "donorName": "Rahul Sharma",
      "status": "completed",
      "userId": {
        "name": "Rahul",
        "email": "rahul@example.com"
      },
      "templeId": {
        "name": "Kashi Vishwanath Temple"
      }
    }
  ]
}
```

---

## 15. Subscriptions System
**Base Path:** `/api/subscriptions`

### Get Subscription Plans
* **Endpoint:** `GET https://api.metagod.in/api/subscriptions`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "651d87e07a685f00123456c0",
      "name": "Divine Plus Plan",
      "price": 1999,
      "features": ["Immersive 360 VR Access", "Priority Booking", "Expert consultations"],
      "image": "https://example.com/divine-plan.jpg"
    }
  ]
}
```

### Create Subscription Plan
* **Endpoint:** `POST https://api.metagod.in/api/subscriptions`
* **Access:** Public (Admin-only intended in prod workflows)
* **Request Body:**
```json
{
  "name": "Divine Plus Plan",
  "price": 1999,
  "features": ["Immersive 360 VR Access", "Priority Booking", "Expert consultations"],
  "image": "https://example.com/divine-plan.jpg"
}
```
* **Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "_id": "651d87e07a685f00123456c0",
    "name": "Divine Plus Plan",
    "price": 1999
  }
}
```

### Update Subscription Plan
* **Endpoint:** `PUT https://api.metagod.in/api/subscriptions/:id`
* **Access:** Public (Admin-only intended)
* **Request Body:** (All fields optional)
```json
{
  "price": 2499
}
```

### Delete Subscription Plan
* **Endpoint:** `DELETE https://api.metagod.in/api/subscriptions/:id`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Plan deleted successfully"
}
```

### Create Razorpay Subscription Payment Order
* **Endpoint:** `POST https://api.metagod.in/api/subscriptions/create-order`
* **Access:** Public
* **Request Body:**
```json
{
  "amount": 1999
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "order_SUB123456",
    "amount": 199900,
    "currency": "INR",
    "receipt": "sub_17364b6e..."
  }
}
```

### Verify Subscription Payment & Activate
* **Endpoint:** `POST https://api.metagod.in/api/subscriptions/verify`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "razorpay_order_id": "order_SUB123456",
  "razorpay_payment_id": "pay_SUB654321",
  "razorpay_signature": "signature_hash_value...",
  "planName": "Divine Plus Plan"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Subscription activated successfully",
  "data": {
    "plan": "Divine Plus Plan",
    "expiry": "2026-07-01T22:30:00.000Z"
  }
}
```

### Upgrade/Downgrade Plan (Prorating via Razorpay)
* **Endpoint:** `PATCH https://api.metagod.in/api/subscriptions/change-plan`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "newPlanId": "plan_rzp_new_plan_id",
  "planName": "Premium Plan"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Subscription successfully updated to Premium Plan",
  "data": {
    "plan": "Premium Plan",
    "subscriptionStatus": "active",
    "subscriptionExpiry": "2026-07-01T22:30:00.000Z"
  }
}
```

---

## 16. Puja Orders System
**Base Path:** `/api/puja-orders`

### Create Puja or Prasad Order
* **Endpoint:** `POST https://api.metagod.in/api/puja-orders`
* **Access:** Public
* **Request Body:**
```json
{
  "itemType": "Puja", 
  "itemId": "652c77a10fdc110012345690",
  "templeId": "651d87e07a685f00123456e0",
  "customerName": "Rahul Sharma",
  "customerPhone": "9999988888",
  "price": 1500
}
```
> Note: itemType can be `Puja` or `Prasad`.
* **Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "_id": "653b87b12abc0012345678aa",
    "itemType": "Puja",
    "itemId": "652c77a10fdc110012345690",
    "customerName": "Rahul Sharma",
    "status": "Ordered"
  }
}
```

### Get All Puja/Prasad Orders
* **Endpoint:** `GET https://api.metagod.in/api/puja-orders`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "653b87b12abc0012345678aa",
      "itemType": "Puja",
      "customerName": "Rahul Sharma",
      "status": "Ordered"
    }
  ]
}
```

### Update Puja/Prasad Order Status
* **Endpoint:** `PUT https://api.metagod.in/api/puja-orders/:id/status`
* **Access:** Public
* **Request Body:**
```json
{
  "status": "Delivered"
}
```
> Statuses allowed: `Ordered`, `Notified`, `Packed`, `Driver Picked`, `Delivered`, `Cancelled`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "653b87b12abc0012345678aa",
    "status": "Delivered"
  }
}
```

---

## 17. Wallet System
**Base Path:** `/api/wallet`

### Get Wallet Details
* **Endpoint:** `GET https://api.metagod.in/api/wallet/details`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "balance": 1500,
  "transactions": [
    {
      "_id": "653b87b12abc0012345678b1",
      "amount": 500,
      "type": "CREDIT",
      "purpose": "Wallet Recharge",
      "description": "Recharged via Razorpay",
      "createdAt": "2026-06-01T21:00:00Z"
    }
  ]
}
```

### Add Funds via Gift Card (Mock code validator)
* **Endpoint:** `POST https://api.metagod.in/api/wallet/add-funds`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "amount": 1000,
  "giftCardCode": "DHARMI-FESTIVE-1000"
}
```
> Note: In the mock implementation, the gift card code must start with `DHARMI` to be accepted.
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Funds added successfully",
  "newBalance": 2500,
  "transaction": {
    "_id": "653b87b12abc0012345678b2",
    "amount": 1000,
    "type": "CREDIT",
    "purpose": "Gift Card Recharge"
  }
}
```

### Pay Using Wallet Balance
* **Endpoint:** `POST https://api.metagod.in/api/wallet/pay`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "amount": 250,
  "purpose": "Aarti Offering Prasad",
  "referenceId": "653b87b12abc0012345678de"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Payment successful",
  "newBalance": 1250,
  "transaction": {
    "_id": "653b87b12abc0012345678b3",
    "amount": 250,
    "type": "DEBIT",
    "purpose": "Aarti Offering Prasad"
  }
}
```

### Verify Wallet Recharge (Credit funds upon successful Razorpay)
* **Endpoint:** `POST https://api.metagod.in/api/wallet/verify-recharge`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "razorpay_order_id": "order_WALL123",
  "razorpay_payment_id": "pay_WALL654",
  "razorpay_signature": "signature_hash_value...",
  "amount": 500
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Wallet recharged successfully",
  "newBalance": 2000,
  "transaction": {
    "_id": "653b87b12abc0012345678b4",
    "amount": 500,
    "type": "CREDIT",
    "purpose": "Wallet Recharge"
  }
}
```

### Developer Cheat Code Recharge
* **Endpoint:** `POST https://api.metagod.in/api/wallet/dev-recharge`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
> Warning: Blocked in production environments. Automatically credits ₹10,000 for development testing.
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "🛠️ Dev Cheat Activated: ₹10,000 added!",
  "newBalance": 11500
}
```

---

## 18. Razorpay Integrations
**Base Path:** `/api/razorpay`

### Create General Order
* **Endpoint:** `POST https://api.metagod.in/api/razorpay/create-order`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "amount": 100,
  "currency": "INR",
  "receipt": "custom_receipt_id_1"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "orderId": "order_rzp_id_987",
  "amount": 10000,
  "currency": "INR"
}
```

### Verify General Payment
* **Endpoint:** `POST https://api.metagod.in/api/razorpay/verify-payment`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "razorpay_order_id": "order_rzp_id_987",
  "razorpay_payment_id": "pay_rzp_id_654",
  "razorpay_signature": "signature_hash..."
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Payment verified successfully"
}
```

### Generic Webhook Handler (Razorpay)
* **Endpoint:** `POST https://api.metagod.in/api/razorpay/webhook`
* **Access:** Public (Secured via webhook signature verification)
* **Headers:** `x-razorpay-signature: <signature>`
* **Response (200 OK):**
```json
{
  "status": "ok"
}
```

---

## 19. Spiritual Activities Tracker
**Base Path:** `/api/spiritual-activities`

### Record Activity
* **Endpoint:** `POST https://api.metagod.in/api/spiritual-activities`
* **Access:** Authenticated (Protected under maintenance guard)
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "serviceName": "Ganga Aarti Live Offering",
  "price": 250,
  "customerName": "Rahul Sharma",
  "category": "Aarti",
  "templeId": "651d87e07a685f00123456e0"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "653b87b12abc0012345678ee",
    "userId": "60c72b2f9b1d8e12345678cd",
    "serviceName": "Ganga Aarti Live Offering",
    "price": 250,
    "customerName": "Rahul Sharma",
    "category": "Aarti",
    "templeId": "651d87e07a685f00123456e0"
  }
}
```

### Get My Logged Activities
* **Endpoint:** `GET https://api.metagod.in/api/spiritual-activities/my`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "653b87b12abc0012345678ee",
      "serviceName": "Ganga Aarti Live Offering",
      "price": 250,
      "category": "Aarti",
      "createdAt": "2026-06-01T21:00:00.000Z"
    }
  ]
}
```

---

## 20. Addresses Management
**Base Path:** `/api/addresses`

### Get My Addresses
* **Endpoint:** `GET https://api.metagod.in/api/addresses`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "653b87b12abc0012345678dd",
      "name": "Rahul Sharma",
      "phone": "9999988888",
      "houseNo": "402",
      "area": "Ganga Vihar",
      "landmark": "Near Shiv Mandir",
      "city": "Varanasi",
      "state": "Uttar Pradesh",
      "pincode": "221001",
      "type": "Home",
      "isDefault": true
    }
  ]
}
```

### Add New Address
* **Endpoint:** `POST https://api.metagod.in/api/addresses`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "name": "Rahul Sharma",
  "phone": "9999988888",
  "houseNo": "402",
  "area": "Ganga Vihar",
  "landmark": "Near Shiv Mandir",
  "city": "Varanasi",
  "state": "Uttar Pradesh",
  "pincode": "221001",
  "type": "Home",
  "isDefault": true
}
```
* **Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "_id": "653b87b12abc0012345678dd",
    "name": "Rahul Sharma",
    "isDefault": true
  }
}
```

### Update Address details
* **Endpoint:** `PUT https://api.metagod.in/api/addresses/:id`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:** (All fields optional)
```json
{
  "houseNo": "502-A"
}
```

### Delete Address
* **Endpoint:** `DELETE https://api.metagod.in/api/addresses/:id`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Address deleted successfully"
}
```

### Set Address as Default Address
* **Endpoint:** `PATCH https://api.metagod.in/api/addresses/:id/set-default`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "653b87b12abc0012345678dd",
    "isDefault": true
  }
}
```

---

## 21. Experts Registry
**Base Path:** `/api/experts`

### List Spiritual Experts
* **Endpoint:** `GET https://api.metagod.in/api/experts`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "652c77a10fdc1100123456aa",
      "name": "Acharya Satish Shastri",
      "title": "Vedic Astrology Expert",
      "category": "Astrology",
      "experience": "15 Years",
      "rating": 4.9,
      "reviews": 120,
      "location": "Varanasi, UP",
      "skills": ["Kundli Reading", "Vastu Shastra"],
      "pricing": {
        "chat": 20,
        "audio": 40,
        "video": 60
      },
      "status": "online",
      "isFeatured": true
    }
  ]
}
```

### Get Expert Details By ID
* **Endpoint:** `GET https://api.metagod.in/api/experts/:id`
* **Access:** Public

### Onboard/Create Expert
* **Endpoint:** `POST https://api.metagod.in/api/experts`
* **Access:** Public (Admin restricted in production logic)
* **Request Body:**
```json
{
  "userId": "60c72b2f9b1d8e12345678cd",
  "name": "Acharya Satish Shastri",
  "title": "Vedic Astrology Expert",
  "category": "Astrology",
  "experience": "15 Years",
  "location": "Varanasi, UP",
  "skills": ["Kundli Reading"],
  "pricing": {
    "chat": 20,
    "audio": 40,
    "video": 60
  },
  "chatPackages": [{"duration": 30, "price": 500}],
  "callPackages": [{"duration": 30, "price": 1000}],
  "videoPackages": [{"duration": 30, "price": 1500}]
}
```
* **Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "_id": "652c77a10fdc1100123456aa",
    "name": "Acharya Satish Shastri"
  }
}
```

### Update Expert details
* **Endpoint:** `PUT https://api.metagod.in/api/experts/:id`
* **Access:** Public

### Delete Expert
* **Endpoint:** `DELETE https://api.metagod.in/api/experts/:id`
* **Access:** Public

---

## 22. Platform Settings CMS
**Base Path:** `/api/settings`

### Get Platform Settings
* **Endpoint:** `GET https://api.metagod.in/api/settings`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "platformName": "MetaGod Sanctuary",
    "supportEmail": "support@metagod.in",
    "supportPhone": "+91 9999988888",
    "maintenanceMode": false,
    "platformFeePercent": 2.5
  }
}
```

### Update Platform Settings
* **Endpoint:** `PUT https://api.metagod.in/api/settings`
* **Access:** Admin / Super Admin only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:** (All fields optional)
```json
{
  "platformName": "MetaGod Devine Sanctuary",
  "maintenanceMode": false
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "platformName": "MetaGod Devine Sanctuary",
    "maintenanceMode": false
  }
}
```

---

## 23. Hero Slides CMS
**Base Path:** `/api/hero`

### Get Carousel Hero Slides
* **Endpoint:** `GET https://api.metagod.in/api/hero`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "652c77a10fdc110012345650",
      "bg": "https://example.com/slide1.jpg",
      "badge": "FLAT 20% OFF",
      "title": "Sacred Darshan Awaits",
      "highlight": "Experience VR",
      "desc": "Immerse in Virtual Reality live events.",
      "cta1": "Explore VR",
      "cta2": "Watch Trailer",
      "link1": "/vr",
      "link2": "/trailer",
      "order": 1
    }
  ]
}
```

### Add Hero Slide
* **Endpoint:** `POST https://api.metagod.in/api/hero`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "bg": "https://example.com/slide1.jpg",
  "badge": "FLAT 20% OFF",
  "title": "Sacred Darshan Awaits",
  "highlight": "Experience VR",
  "desc": "Immerse in Virtual Reality live events.",
  "cta1": "Explore VR",
  "cta2": "Watch Trailer",
  "link1": "/vr",
  "link2": "/trailer",
  "order": 1
}
```

### Update Hero Slide Details
* **Endpoint:** `PUT https://api.metagod.in/api/hero/:id`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

### Delete Hero Slide
* **Endpoint:** `DELETE https://api.metagod.in/api/hero/:id`
* **Access:** Admin Only
* **Headers:** `Authorization: Bearer <accessToken>`

---

## 24. VR Experiences Management
**Base Path:** `/api/vr-experiences`

### List VR Experiences
* **Endpoint:** `GET https://api.metagod.in/api/vr-experiences`
* **Access:** Public
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "652c77a10fdc1100123456aa",
      "title": "Somnath Temple 360",
      "tag": "VR Immersive",
      "desc": "Immersive Virtual Darshan of Somnath temple Gujarat.",
      "img": "https://example.com/somnath.jpg",
      "storeLink": "https://oculus.com/somnath",
      "isAvailable": true
    }
  ]
}
```

### Get VR Experience details
* **Endpoint:** `GET https://api.metagod.in/api/vr-experiences/:id`
* **Access:** Public

### Add VR Experience
* **Endpoint:** `POST https://api.metagod.in/api/vr-experiences`
* **Access:** Public (Admin restricted in production logic)
* **Request Body:**
```json
{
  "title": "Somnath Temple 360",
  "tag": "VR Immersive",
  "desc": "Immersive Virtual Darshan of Somnath temple Gujarat.",
  "img": "https://example.com/somnath.jpg",
  "storeLink": "https://oculus.com/somnath",
  "isAvailable": true
}
```

### Update VR Experience
* **Endpoint:** `PUT https://api.metagod.in/api/vr-experiences/:id`
* **Access:** Public

### Delete VR Experience
* **Endpoint:** `DELETE https://api.metagod.in/api/vr-experiences/:id`
* **Access:** Public

---

## 25. Consultations & Expert Live Chat
**Base Path:** `/api/consultations`

### Get Consultation Chat Sessions List
* **Endpoint:** `GET https://api.metagod.in/api/consultations/sessions`
* **Access:** Authenticated (User or Expert)
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "userId": "60c72b2f9b1d8e12345678cd",
      "expertId": "652c77a10fdc1100123456aa",
      "userName": "Rahul Sharma",
      "expertName": "Acharya Satish Shastri",
      "lastMessage": "May the blessings of Lord Shiva align your stars.",
      "lastTimestamp": "2026-06-01T22:00:00Z",
      "remainingMinutes": 10,
      "remainingSeconds": 600
    }
  ]
}
```

### Get My Purchased Consultation Transactions
* **Endpoint:** `GET https://api.metagod.in/api/consultations/transactions/my`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "653b87b12abc0012345678cc",
      "expertId": {
        "name": "Acharya Satish Shastri",
        "title": "Vedic Astrology Expert"
      },
      "amount": 500,
      "minutes": 30,
      "type": "chat",
      "status": "completed",
      "createdAt": "2026-06-01T15:30:00Z"
    }
  ]
}
```

### Buy Consultation Package Minutes (Mock Gateway check)
* **Endpoint:** `POST https://api.metagod.in/api/consultations/buy`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "expertId": "652c77a10fdc1100123456aa",
  "minutes": 30,
  "amount": 500,
  "type": "chat" 
}
```
> Note: `type` can be `chat`, `video`, `audio` or `call`. Amount & duration validation matches against expert packages dynamically.
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "userId": "60c72b2f9b1d8e12345678cd",
    "expertId": "652c77a10fdc1100123456aa",
    "chatSeconds": 1800,
    "remainingSeconds": 1800
  },
  "message": "Successfully purchased 30 minutes of chat consultation for Acharya Satish Shastri"
}
```

### Get Consultation Remaining Balance With Expert
* **Endpoint:** `GET https://api.metagod.in/api/consultations/balance/:expertId`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "remainingMinutes": 30,
    "remainingSeconds": 1800,
    "chatSeconds": 1800,
    "audioSeconds": 0,
    "videoSeconds": 0
  }
}
```

### Get Consultation Chat History Log
* **Endpoint:** `GET https://api.metagod.in/api/consultations/history/:expertId`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Query Parameters:** (Optional for Admin/Experts)
  * `userId` (Retrieve a specific user's chat history)
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "653b87b12abc0012345678cf",
      "userId": "60c72b2f9b1d8e12345678cd",
      "expertId": "652c77a10fdc1100123456aa",
      "sender": "user",
      "message": "Namaste Acharya Ji, please review my health alignment.",
      "createdAt": "2026-06-01T21:58:00Z"
    },
    {
      "_id": "653b87b12abc0012345678cg",
      "userId": "60c72b2f9b1d8e12345678cd",
      "expertId": "652c77a10fdc1100123456aa",
      "sender": "expert",
      "message": "May the blessings of Lord Shiva align your stars.",
      "createdAt": "2026-06-01T22:00:00Z"
    }
  ]
}
```

### Expert Only: Get My Cumulative Billing Revenue
* **Endpoint:** `GET https://api.metagod.in/api/consultations/revenue`
* **Access:** Expert Profile Owner Only
* **Headers:** `Authorization: Bearer <accessToken>`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "stats": {
      "totalRevenue": 25000,
      "totalMinutesSold": 1500
    },
    "buyerCount": 35,
    "recentTransactions": []
  }
}
```

---

## 26. AI Chat & Sanctuary Oracle Proxy

### Sanctuary Oracle (Intelligent Assistant with Gemini Fallbacks)
* **Endpoint:** `POST https://api.metagod.in/api/chat`
* **Access:** Public
* **Request Body:**
```json
{
  "message": "How do I book a puja?",
  "language": "English",
  "history": [
    {
      "role": "user",
      "text": "Hello"
    },
    {
      "role": "oracle",
      "text": "Namaste seeker. I am the Sanctuary Oracle."
    }
  ]
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "reply": "Pranam. Booking a sacred Pooja or Seva is a beautiful way to connect with the divine. You can easily schedule these rituals through the 'Temple Services' section, or directly while viewing the 'Live Darshan' page."
  }
}
```

### AI Chat Proxy (Direct External AI Server Routing)
* **Endpoint:** `POST https://api.metagod.in/api/ai/chat`
* **Access:** Public
* **Request Body:**
```json
{
  "message": "What is the significance of Kedarnath?",
  "user_id": "optional_user_id_here",
  "include_jyotish": true
}
```
* **Response (200 OK):**
```json
{
  "response": "Kedarnath is one of the twelve Jyotirlingas of Lord Shiva..."
}
```

---

## 27. Image Upload Service
**Base Path:** `/api/upload`

### Upload Image (Multipart Form)
* **Endpoint:** `POST https://api.metagod.in/api/upload/image`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`, `Content-Type: multipart/form-data`
* **Query Parameters:** (Optional)
  * `oldUrl` (If specified, will delete the previous image from Cloudinary)
  * `folder` (Cloudinary folder path, defaults to `temple-uploads`)
* **Request Body:** (Form Data)
  * `image`: `[File Binary]`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "url": "https://res.cloudinary.com/metagod/image/upload/v12345/temple-uploads/abcd.jpg",
    "public_id": "temple-uploads/abcd"
  }
}
```

### Delete Image from Cloudinary
* **Endpoint:** `DELETE https://api.metagod.in/api/upload/image`
* **Access:** Authenticated
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "url": "https://res.cloudinary.com/metagod/image/upload/v12345/temple-uploads/abcd.jpg"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Image deleted"
}
```

---

## 28. Integrations Webhooks
**Base Path:** `/api/webhooks`

### Skyrocket Courier Webhook Update
* **Endpoint:** `POST https://api.metagod.in/api/webhooks/skyrocket`
* **Access:** Public
* **Request Body:**
```json
{
  "orderId": "653b87b12abc0012345678de",
  "status": "Shipped",
  "trackingUrl": "https://skyrocket.co/track/123"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Webhook processed successfully"
}
```

### Shiprocket Tracking Webhook Update
* **Endpoint:** `POST https://api.metagod.in/api/webhooks/shiprocket`
* **Access:** Public
* **Request Body:**
```json
{
  "awb": "SR9876543210",
  "current_status": "OUT FOR DELIVERY"
}
```
> Internal state changes mapped: `OUT FOR DELIVERY` -> `Out for Delivery`, `DELIVERED` -> `Delivered`, `PICKED UP` -> `Driver Picked`, `SHIPPED` -> `Shipped`.
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Status updated to Out for Delivery"
}
```

### Razorpay Webhook Update (Subscriptions charging/cancelled events)
* **Endpoint:** `POST https://api.metagod.in/api/webhooks/razorpay`
* **Access:** Public (Signature Verified)
* **Headers:** `x-razorpay-signature: <signature>`
* **Request Body:** (Razorpay Webhook Payload Structure)
```json
{
  "event": "subscription.charged",
  "payload": {
    "subscription": {
      "entity": {
        "id": "sub_rzp_id_123",
        "current_end": 1740000000,
        "notes": {
          "userId": "60c72b2f9b1d8e12345678cd",
          "planName": "Divine Plus Plan"
        }
      }
    }
  }
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Webhook verified and processed successfully"
}
```

---

## 29. Bookings Module (Inactive)
**Base Path:** `/api/bookings`
> ⚠️ **Warning:** This module is defined in code but the router is currently **not mounted** in `app.js`.

### Create Booking
* **Endpoint:** `POST https://api.metagod.in/api/bookings`
* **Access:** Authenticated (Defunct)
* **Headers:** `Authorization: Bearer <accessToken>`
* **Request Body:**
```json
{
  "templeId": "651d87e07a685f00123456e0",
  "bookingDate": "2026-06-15",
  "slot": "Morning"
}
```

### Get My Bookings
* **Endpoint:** `GET https://api.metagod.in/api/bookings/my-bookings`
* **Access:** Authenticated (Defunct)

### Get All Bookings
* **Endpoint:** `GET https://api.metagod.in/api/bookings`
* **Access:** Authenticated (Defunct)
