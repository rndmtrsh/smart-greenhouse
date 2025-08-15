# 🌱 Smart Greenhouse API Documentation

<div align="center">

**API Documentation untuk Sistem Monitoring Greenhouse**  
*Real-time monitoring untuk tanaman Cabai, Melon, dan Selada*

![Version](https://img.shields.io/badge/version-1.0.0-green.svg)
![Status](https://img.shields.io/badge/status-active-brightgreen.svg)

</div>

---

## 📋 Daftar Isi

- [🌐 Base URL](#-base-url)
- [🔐 Autentikasi](#-autentikasi)
- [📡 Endpoint API](#-endpoint-api)
  - [🏥 Health Check](#-health-check)
  - [🗺️ Manajemen Zona](#️-manajemen-zona)
  - [📱 Manajemen Perangkat](#-manajemen-perangkat)
  - [📊 Data Sensor](#-data-sensor)
  - [🌿 Manajemen Tanaman](#-manajemen-tanaman)
- [⚠️ Error Handling](#️-error-handling)
- [🔧 Format Data](#-format-data)
- [💻 Contoh Integrasi](#-contoh-integrasi)

---

## 🌐 Base URL

**Development:**
```
http://localhost:5000
```

**Production:**
```
https://kedairekagreenhouse.my.id
```

---

## 🔐 Autentikasi

Semua endpoint API (kecuali `/health` `/api/ping`) memerlukan **API Key Authentication**.

### 📝 Header yang Diperlukan
```
X-API-KEY: your_api_key_here
Content-Type: application/json
```

### ✅ Contoh Request
```bash
curl -X GET "https://kedairekagreenhouse.my.id/api/zones" \
  -H "X-API-KEY: your_api_key_here" \
  -H "Content-Type: application/json"
```

### ❌ Response Unauthorized
```json
{
  "error": "Unauthorized"
}
```

---

## 📡 Endpoint API

### 🏥 Health Check

#### `GET /health`
> ✅ **Public endpoint** - Tidak memerlukan API key

Memeriksa kesehatan sistem dan koneksi database.

**✅ Success Response (200):**
```json
{
  "status": "healthy",
  "database": "connected",
  "tunnel": "active"
}
```

**❌ Error Response (500):**
```json
{
  "status": "unhealthy",
  "error": "Database connection failed"
}
```

---

#### `GET /api/ping`
> ✅ **Public endpoint** - Tidak memerlukan API key

Health check dengan autentikasi.

**✅ Response (200):**
```json
{
  "message": "AMAN COK",
  "status": "healthy"
}
```

---

### 🗺️ Manajemen Zona

#### `GET /api/zones`
> 🔒 **Requires API key**

Mengambil daftar semua zona dengan informasi tanaman.

**✅ Response (200):**
```json
{
  "zones": [
    {
      "zone_id": 1,
      "zone_code": "CZ1",
      "zone_label": "Zona Cabai 1",
      "location_description": "Baris 1",
      "plant_name": "Cabai",
      "media_type": "Tanah",
      "plant_description": "Cabai media tanah polybag"
    },
    {
      "zone_id": 7,
      "zone_code": "MZ1",
      "zone_label": "Zona Melon 1",
      "location_description": "Rakit A1",
      "plant_name": "Melon",
      "media_type": "Hidroponik",
      "plant_description": "Melon sistem hidroponik"
    },
    {
      "zone_id": 14,
      "zone_code": "GZ",
      "zone_label": "Zona Greenhouse Umum",
      "location_description": "3 titik deteksi",
      "plant_name": null,
      "media_type": null,
      "plant_description": null
    }
  ],
  "count": 14
}
```

---

#### `GET /api/zones/{zone_code}`
> 🔒 **Requires API key**

Mengambil detail zona spesifik beserta perangkat yang ada.

**Parameters:**
- `zone_code` *(string)*: Kode zona (CZ1, CZ2, MZ1, HZ1, GZ, dll.)

**✅ Success Response (200):**
```json
{
  "zone": {
    "zone_id": 1,
    "zone_code": "CZ1",
    "zone_label": "Zona Cabai 1",
    "location_description": "Baris 1",
    "plant_name": "Cabai",
    "media_type": "Tanah",
    "plant_description": "Cabai media tanah polybag"
  },
  "devices": [
    {
      "device_id": 1,
      "dev_eui": "device_eui_here",
      "code": "CZ1",
      "description": "Device Cabai Zona 1"
    }
  ]
}
```

**❌ Error Response (404):**
```json
{
  "error": "Zone not found"
}
```

---

### 📱 Manajemen Perangkat

#### `GET /api/devices`
> 🔒 **Requires API key**

Mengambil daftar semua perangkat IoT beserta informasi zona dan tanaman.

**✅ Response (200):**
```json
{
  "devices": [
    {
      "device_id": 1,
      "dev_eui": "device_eui_here",
      "code": "CZ1",
      "description": "Device Cabai Zona 1",
      "zone_code": "CZ1",
      "zone_label": "Zona Cabai 1",
      "plant_name": "Cabai"
    },
    {
      "device_id": 7,
      "dev_eui": "device_eui_here",
      "code": "MZ1",
      "description": "Device Melon Zona 1",
      "zone_code": "MZ1",
      "zone_label": "Zona Melon 1",
      "plant_name": "Melon"
    }
  ],
  "count": 14
}
```

---

#### `GET /api/devices/{device_code}/sensors`
> 🔒 **Requires API key**

Mengambil daftar sensor yang terpasang pada perangkat tertentu.

**Parameters:**
- `device_code` *(string)*: Kode perangkat (CZ1, CZ2, MZ1, HZ1, GZ1, dll.)

**✅ Success Response (200):**
```json
{
  "device_code": "CZ1",
  "sensors": [
    {
      "device_sensor_id": 1,
      "sensor_label": "Sensor 1",
      "sensor_order": 1,
      "sensor_type": "pH",
      "unit": "",
      "sensor_model": "Gravity DF Robot"
    },
    {
      "device_sensor_id": 2,
      "sensor_label": "Sensor 2",
      "sensor_order": 2,
      "sensor_type": "Soil Moisture",
      "unit": "%",
      "sensor_model": "Gravity DF Robot"
    },
    {
      "device_sensor_id": 3,
      "sensor_label": "Sensor 3",
      "sensor_order": 3,
      "sensor_type": "EC",
      "unit": "mS/cm",
      "sensor_model": "DFROBOT-EC"
    },
    {
      "device_sensor_id": 4,
      "sensor_label": "Sensor 4",
      "sensor_order": 4,
      "sensor_type": "Temperature",
      "unit": "°C",
      "sensor_model": "DS18B20/SHT31-D"
    }
  ]
}
```

**❌ Error Response (404):**
```json
{
  "error": "Device not found or no sensors"
}
```

**💡 Sensor Configuration per Plant:**
- **🌶️ Cabai (CZ1-CZ6)**: pH, Soil Moisture, EC, Temperature
- **🍈 Melon (MZ1-MZ5)**: pH, EC, Temperature  
- **🥬 Selada (HZ1-HZ2)**: pH, EC, Temperature
- **🏠 Greenhouse (GZ1)**: Temperature, Light

---

### 📊 Data Sensor

#### `GET /api/latest-readings`
> 🔒 **Requires API key**

Mengambil pembacaan sensor terbaru untuk semua perangkat (satu reading terakhir per device).

**✅ Response (200):**
```json
{
  "readings": [
    {
      "reading_id": 1,
      "device_code": "CZ1",
      "dev_eui": "device_eui_here",
      "zone_code": "CZ1",
      "zone_label": "Zona Cabai 1",
      "plant_name": "Cabai",
      "encoded_data": "01F402BC006400C8",
      "timestamp": "2025-08-15T14:30:25.123456"
    },
    {
      "reading_id": 2,
      "device_code": "GZ1",
      "dev_eui": "device_eui_here",
      "zone_code": "GZ",
      "zone_label": "Zona Greenhouse Umum",
      "plant_name": null,
      "encoded_data": "00C8012C",
      "timestamp": "2025-08-15T14:28:45.567890"
    }
  ],
  "count": 3
}
```

---

#### `GET /api/readings/{device_code}`
> 🔒 **Requires API key**

Mengambil riwayat pembacaan sensor untuk perangkat tertentu dengan dukungan pagination.

**Parameters:**
- `device_code` *(string)*: Kode perangkat
- `limit` *(integer, optional)*: Jumlah data per halaman (default: 50, max: 1000)
- `offset` *(integer, optional)*: Offset data (default: 0)

**Query Parameters:**
```
?limit=10&offset=0
```

**✅ Response (200):**
```json
{
  "device_code": "CZ1",
  "readings": [
    {
      "reading_id": 105,
      "encoded_data": "01F402BC006400C8",
      "timestamp": "2025-08-15T14:30:25.123456"
    },
    {
      "reading_id": 104,
      "encoded_data": "01E802A0005A00B4",
      "timestamp": "2025-08-15T14:25:15.234567"
    }
  ],
  "pagination": {
    "limit": 5,
    "offset": 0,
    "total": 1250,
    "has_more": true
  }
}
```

**🔄 Pagination Example:**
```
# Halaman pertama (0-49)
GET /api/readings/CZ1?limit=50&offset=0

# Halaman kedua (50-99)  
GET /api/readings/CZ1?limit=50&offset=50
```

---

### 🌿 Manajemen Tanaman

#### `GET /api/plants`
> 🔒 **Requires API key**

Mengambil daftar semua jenis tanaman beserta jumlah zona yang dimiliki.

**✅ Response (200):**
```json
{
  "plants": [
    {
      "plant_id": 1,
      "name": "Cabai",
      "media_type": "Tanah",
      "description": "Cabai media tanah polybag",
      "zone_count": 6
    },
    {
      "plant_id": 2,
      "name": "Melon",
      "media_type": "Hidroponik",
      "description": "Melon sistem hidroponik",
      "zone_count": 5
    },
    {
      "plant_id": 3,
      "name": "Selada",
      "media_type": "Hidroponik",
      "description": "Selada hidroponik NFT",
      "zone_count": 2
    }
  ],
  "count": 3
}
```

---

## ⚠️ Error Handling

### 📋 Status Codes
| Code | Status | Deskripsi |
|------|--------|-----------|
| 🟢 **200** | OK | Request berhasil |
| 🔴 **401** | Unauthorized | API key tidak valid atau missing |
| 🔴 **404** | Not Found | Resource tidak ditemukan |
| 🔴 **405** | Method Not Allowed | HTTP method tidak diizinkan |
| 🔴 **500** | Internal Server Error | Error server internal |

### 📝 Format Error Response
```json
{
  "error": "Deskripsi error yang jelas"
}
```

### 🔍 Contoh Error Responses

**🔴 401 - Unauthorized:**
```json
{
  "error": "Unauthorized"
}
```

**🔴 404 - Zone Not Found:**
```json
{
  "error": "Zone not found"
}
```

**🔴 404 - Device Not Found:**
```json
{
  "error": "Device not found or no sensors"
}
```

**🔴 404 - Endpoint Not Found:**
```json
{
  "error": "Endpoint not found"
}
```

**🔴 405 - Method Not Allowed:**
```json
{
  "error": "Method not allowed"
}
```

**🔴 500 - Internal Server Error:**
```json
{
  "error": "Internal server error"
}
```

---

## 🔧 Format Data

### 📡 Encoded Data (HEX Format)
Data sensor disimpan dalam format **HEX string** sesuai urutan sensor pada setiap perangkat.

#### 🌶️ **Cabai Devices (CZ1-CZ6)** - 4 Sensor
```
Encoded Data: "01F402BC006400C8" (16 characters HEX)

Breakdown:
├── 01F4 → pH        = 500 → 5.00 pH
├── 02BC → Moisture  = 700 → 70.0%
├── 0064 → EC        = 100 → 1.00 mS/cm
└── 00C8 → Temp      = 200 → 20.0°C
```

#### 🍈 **Melon/Selada Devices** - 3 Sensor
```
Encoded Data: "01F4006400C8" (12 characters HEX)

Breakdown:
├── 01F4 → pH    = 500 → 5.00 pH
├── 0064 → EC    = 100 → 1.00 mS/cm
└── 00C8 → Temp  = 200 → 20.0°C
```

#### 🏠 **Greenhouse Device (GZ1)** - 2 Sensor
```
Encoded Data: "00C8012C" (8 characters HEX)

Breakdown:
├── 00C8 → Temp  = 200 → 20.0°C
└── 012C → Light = 300 → 300 lux
```

---

## 💻 Contoh Integrasi

### 🚀 JavaScript/Fetch API

#### Basic API Client
```javascript
class GreenhouseAPI {
    constructor(baseURL = 'https://kedairekagreenhouse.my.id', apiKey = 'your_api_key_here') {
        this.baseURL = baseURL;
        this.apiKey = apiKey;
    }

    async request(endpoint, options = {}) {
        const url = `${this.baseURL}${endpoint}`;
        const config = {
            headers: {
                'X-API-KEY': this.apiKey,
                'Content-Type': 'application/json',
                ...options.headers
            },
            ...options
        };

        try {
            const response = await fetch(url, config);
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            return await response.json();
        } catch (error) {
            console.error(`API request failed:`, error);
            throw error;
        }
    }

    // API Methods
    async getZones() {
        return this.request('/api/zones');
    }

    async getLatestReadings() {
        return this.request('/api/latest-readings');
    }

    async getDeviceReadings(deviceCode, limit = 50, offset = 0) {
        return this.request(`/api/readings/${deviceCode}?limit=${limit}&offset=${offset}`);
    }

    // Decode HEX data
    decodeHexData(hexString, deviceCode) {
        if (deviceCode.startsWith('CZ')) {  // Cabai
            return {
                pH: parseInt(hexString.substr(0, 4), 16) / 100,
                moisture: parseInt(hexString.substr(4, 4), 16) / 10,
                ec: parseInt(hexString.substr(8, 4), 16) / 100,
                temperature: parseInt(hexString.substr(12, 4), 16) / 10
            };
        } 
        
        if (deviceCode.startsWith('MZ') || deviceCode.startsWith('HZ')) {
            return {
                pH: parseInt(hexString.substr(0, 4), 16) / 100,
                ec: parseInt(hexString.substr(4, 4), 16) / 100,
                temperature: parseInt(hexString.substr(8, 4), 16) / 10
            };
        }
        
        if (deviceCode.startsWith('GZ')) {  // Greenhouse
            return {
                temperature: parseInt(hexString.substr(0, 4), 16) / 10,
                light: parseInt(hexString.substr(4, 4), 16)
            };
        }
        
        return null;
    }
}
```

### ⚛️ React Hook Example

```javascript
import { useState, useEffect } from 'react';

const useGreenhouseAPI = () => {
    const [data, setData] = useState({
        zones: [],
        devices: [],
        latestReadings: []
    });
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    const api = new GreenhouseAPI('https://kedairekagreenhouse.my.id', 'your_api_key_here');

    const fetchData = async () => {
        try {
            setLoading(true);
            const [zones, devices, readings] = await Promise.all([
                api.getZones(),
                api.request('/api/devices'),
                api.getLatestReadings()
            ]);

            setData({
                zones: zones.zones,
                devices: devices.devices,
                latestReadings: readings.readings
            });
        } catch (err) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchData();
        const interval = setInterval(fetchData, 30000);
        return () => clearInterval(interval);
    }, []);

    return { data, loading, error, refetch: fetchData };
};
```

### 🐍 Python Example

```python
import requests
from typing import Dict, List

class GreenhouseAPI:
    def __init__(self, base_url: str = "https://kedairekagreenhouse.my.id", api_key: str = "your_api_key_here"):
        self.base_url = base_url.rstrip('/')
        self.session = requests.Session()
        self.session.headers.update({
            'X-API-KEY': api_key,
            'Content-Type': 'application/json'
        })

    def _request(self, endpoint: str) -> Dict:
        url = f"{self.base_url}{endpoint}"
        try:
            response = self.session.get(url, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            raise Exception(f"API request failed: {e}")

    def get_latest_readings(self) -> List[Dict]:
        data = self._request('/api/latest-readings')
        return data['readings']

    def decode_hex_data(self, hex_string: str, device_code: str) -> Dict:
        if device_code.startswith('CZ'):  # Cabai
            return {
                'pH': int(hex_string[0:4], 16) / 100,
                'moisture': int(hex_string[4:8], 16) / 10,
                'ec': int(hex_string[8:12], 16) / 100,
                'temperature': int(hex_string[12:16], 16) / 10
            }
        elif device_code.startswith(('MZ', 'HZ')):  # Melon/Selada
            return {
                'pH': int(hex_string[0:4], 16) / 100,
                'ec': int(hex_string[4:8], 16) / 100,
                'temperature': int(hex_string[8:12], 16) / 10
            }
        elif device_code.startswith('GZ'):  # Greenhouse
            return {
                'temperature': int(hex_string[0:4], 16) / 10,
                'light': int(hex_string[4:8], 16)
            }
        else:
            return {'error': 'Unknown device type'}

# Usage Example
api = GreenhouseAPI()
readings = api.get_latest_readings()

for reading in readings:
    device = reading['device_code']
    decoded = api.decode_hex_data(reading['encoded_data'], device)
    print(f"{device}: {decoded}")
```

---

<div align="center">

---

**📋 API Documentation v1.0.0**  
*Smart Greenhouse Monitoring System*

🌱 **Real-time Monitoring** | 📊 **RESTful API** | 🔒 **Secure Authentication**

---

</div>