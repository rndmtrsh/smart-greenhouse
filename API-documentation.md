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

Semua endpoint API (kecuali `/health`) memerlukan **API Key Authentication**.

### 📝 Header yang Diperlukan
```
X-API-KEY: your_api_key_here
Content-Type: application/json
```

### ✅ Contoh Request
```bash
curl -X GET "https://kedairekagreenhouse.my.id/api/devices" \
  -H "X-API-KEY: your_api_key_here" \
  -H "Content-Type: application/json"
```

### ❌ Response Unauthorized
```json
{
  "status": "error",
  "message": "Unauthorized"
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

Health check sederhana.

**✅ Response (200):**
```json
{
  "status": "healthy",
  "message": "AMAN"
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
      "device_id": 5,
      "dev_eui": "device_eui_here",
      "code": "MZ1",
      "description": "Device Melon Zona 1",
      "zone_code": "MZ1",
      "zone_label": "Zona Melon 1",
      "plant_name": "Melon"
    },
    {
      "device_id": 7,
      "dev_eui": "device_eui_here",
      "code": "SZ12",
      "description": "Device Selada Zona 1-2",
      "zone_code": "SZ12",
      "zone_label": "Zona Selada 1-2",
      "plant_name": "Selada"
    },
    {
      "device_id": 10,
      "dev_eui": "device_eui_here",
      "code": "GZ1",
      "description": "Device Greenhouse",
      "zone_code": "GZ1",
      "zone_label": "Zona Greenhouse Umum",
      "plant_name": null
    }
  ],
  "count": 10
}
```

---

#### `GET /api/devices/{device_code}/sensors`
> 🔒 **Requires API key**

Mengambil daftar sensor yang terpasang pada perangkat tertentu.

**Parameters:**
- `device_code` *(string)*: Kode perangkat (CZ1-CZ4, MZ1-MZ2, SZ12/SZ3/SZ4, GZ1)

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

**💡 Device Configuration yang Tersedia:**
- **🌶️ Cabai**: CZ1, CZ2, CZ3, CZ4 (pH, Soil Moisture, EC, Temperature)
- **🍈 Melon**: MZ1, MZ2 (pH, EC, Temperature)  
- **🥬 Selada**: SZ12, SZ3, SZ4 (pH, EC, Temperature)
- **🏠 Greenhouse**: GZ1 (Temperature, Humidity, Light)

---

### 📊 Data Sensor

#### `GET /api/latest-readings`
> 🔒 **Requires API key**

Mengambil pembacaan sensor terbaru untuk semua perangkat (satu reading terakhir per device).

**✅ Response (200):**
```json
{
  "status": "success",
  "count": 3,
  "readings": [
    {
      "reading_id": 1,
      "zone_code": "CZ1",
      "encoded_data": "01F402BC006400C8",
      "timestamp": "2025-08-15T14:30:25.123456"
    },
    {
      "reading_id": 2,
      "zone_code": "MZ1",
      "encoded_data": "01F4006400C8",
      "timestamp": "2025-08-15T14:29:10.987654"
    },
    {
      "reading_id": 3,
      "zone_code": "GZ1",
      "encoded_data": "00C801F4012C",
      "timestamp": "2025-08-15T14:28:45.567890"
    }
  ]
}
```

---

#### `GET /api/latest-readings/{device_code}`
> 🔒 **Requires API key**

Mengambil pembacaan sensor terbaru untuk perangkat tertentu.

**Parameters:**
- `device_code` *(string)*: Kode perangkat (CZ1-CZ4, MZ1-MZ2, SZ12/SZ3/SZ4, GZ1)

**✅ Response (200):**
```json
{
  "status": "success",
  "device_code": "CZ1",
  "reading": {
    "encoded_data": "01F402BC006400C8",
    "timestamp": "2025-08-15T14:30:25.123456"
  }
}
```

**❌ Error Response (404):**
```json
{
  "status": "error",
  "message": "Device not found"
}
```

---

#### `GET /api/{device_code}/24`
> 🔒 **Requires API key**

Mengambil data sensor dalam 24 jam terakhir dengan interval 4 jam.

**Parameters:**
- `device_code` *(string)*: Kode perangkat

**✅ Response (200):**
```json
{
  "status": "success",
  "device_code": "CZ1",
  "interval": "4h",
  "readings": [
    {
      "encoded_data": "01F402BC006400C8",
      "timestamp": "2025-08-15T14:30:25.123456"
    },
    {
      "encoded_data": "01E802A0005A00B4",
      "timestamp": "2025-08-15T10:30:25.123456"
    },
    {
      "encoded_data": "01DC029C005600B0",
      "timestamp": "2025-08-15T06:30:25.123456"
    }
  ]
}
```

---

#### `GET /api/{device_code}/7`
> 🔒 **Requires API key**

Mengambil rata-rata data sensor dalam 7 hari terakhir per hari.

**Parameters:**
- `device_code` *(string)*: Kode perangkat

**✅ Response (200):**
```json
{
  "status": "success",
  "device_code": "CZ1",
  "interval": "1d",
  "readings": [
    {
      "day": "2025-08-15",
      "avg_encoded": 500.5,
      "sample_time": "2025-08-15T08:00:00.000000"
    },
    {
      "day": "2025-08-14",
      "avg_encoded": 485.2,
      "sample_time": "2025-08-14T08:00:00.000000"
    }
  ]
}
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
      "zone_count": 4
    },
    {
      "plant_id": 2,
      "name": "Melon",
      "media_type": "Hidroponik",
      "description": "Melon sistem hidroponik",
      "zone_count": 2
    },
    {
      "plant_id": 3,
      "name": "Selada",
      "media_type": "Hidroponik",
      "description": "Selada hidroponik NFT",
      "zone_count": 3
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

#### 🌶️ **Cabai Devices (CZ1-CZ4)** - 4 Sensor
```
Encoded Data: "01F402BC006400C8" (16 characters HEX)

Breakdown:
├── 01F4 → pH        = 500 → 5.00 pH
├── 02BC → Moisture  = 700 → 70.0%
├── 0064 → EC        = 100 → 1.00 mS/cm
└── 00C8 → Temp      = 200 → 20.0°C
```

#### 🍈 **Melon Devices (MZ1-MZ2)** - 3 Sensor
```
Encoded Data: "01F4006400C8" (12 characters HEX)

Breakdown:
├── 01F4 → pH    = 500 → 5.00 pH
├── 0064 → EC    = 100 → 1.00 mS/cm
└── 00C8 → Temp  = 200 → 20.0°C
```

#### 🥬 **Selada Devices (SZ12, SZ3, SZ4)** - 3 Sensor
```
Encoded Data: "01C8004B00A0" (12 characters HEX)

Breakdown:
├── 01C8 → pH    = 456 → 4.56 pH
├── 004B → EC    = 75  → 0.75 mS/cm
└── 00A0 → Temp  = 160 → 16.0°C
```

#### 🏠 **Greenhouse Device (GZ1)** - 3 Sensor
```
Encoded Data: "00C801F4012C" (12 characters HEX)

Breakdown:
├── 00C8 → Temp     = 200 → 20.0°C
├── 01F4 → Humidity = 500 → 50.0%
└── 012C → Light    = 300 → 300 lux
```

### 🔧 **Mapping Antares ke Database**
Beberapa device memiliki nama yang berbeda di platform Antares:

| Database Code | Antares Name | Plant Type |
|---------------|--------------|------------|
| CZ1-CZ4 | CZ1-CZ4 | Cabai |
| MZ1 | MZ1 | Melon |
| MZ2 | M2 | Melon |
| SZ12, SZ3, SZ4 | SZ12, SZ3, SZ4 | Selada |
| GZ1 | GZ1 | Greenhouse |

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
    async getDevices() {
        return this.request('/api/devices');
    }

    async getLatestReadings() {
        return this.request('/api/latest-readings');
    }

    async getDeviceLatestReading(deviceCode) {
        return this.request(`/api/latest-readings/${deviceCode}`);
    }

    async get24HourData(deviceCode) {
        return this.request(`/api/${deviceCode}/24`);
    }

    async get7DayData(deviceCode) {
        return this.request(`/api/${deviceCode}/7`);
    }

    async getPlants() {
        return this.request('/api/plants');
    }

    // Decode HEX data
    decodeHexData(hexString, deviceCode) {
        if (deviceCode.startsWith('CZ')) {  // Cabai (4 sensors)
            return {
                pH: parseInt(hexString.substr(0, 4), 16) / 100,
                moisture: parseInt(hexString.substr(4, 4), 16) / 10,
                ec: parseInt(hexString.substr(8, 4), 16) / 100,
                temperature: parseInt(hexString.substr(12, 4), 16) / 10
            };
        }
        
        if (deviceCode.startsWith('MZ') || deviceCode.startsWith('SZ')) {  // Melon/Selada (3 sensors)
            return {
                pH: parseInt(hexString.substr(0, 4), 16) / 100,
                ec: parseInt(hexString.substr(4, 4), 16) / 100,
                temperature: parseInt(hexString.substr(8, 4), 16) / 10
            };
        }
        
        if (deviceCode.startsWith('GZ')) {  // Greenhouse (3 sensors)
            return {
                temperature: parseInt(hexString.substr(0, 4), 16) / 10,
                humidity: parseInt(hexString.substr(4, 4), 16) / 10,
                light: parseInt(hexString.substr(8, 4), 16)
            };
        }
        
        return null;
    }
}

// Usage Example
const api = new GreenhouseAPI();

// Get latest readings for all devices
api.getLatestReadings()
    .then(data => {
        data.readings.forEach(reading => {
            const decoded = api.decodeHexData(reading.encoded_data, reading.zone_code);
            console.log(`${reading.zone_code}:`, decoded);
        });
    })
    .catch(error => console.error('Error:', error));

// Get 24-hour data for specific device
api.get24HourData('CZ1')
    .then(data => {
        console.log('24-hour data for CZ1:', data.readings);
    })
    .catch(error => console.error('Error:', error));
```

### ⚛️ React Hook Example

```javascript
import { useState, useEffect } from 'react';

const useGreenhouseAPI = () => {
    const [data, setData] = useState({
        devices: [],
        latestReadings: [],
        plants: []
    });
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    const api = new GreenhouseAPI();

    const fetchData = async () => {
        try {
            setLoading(true);
            const [devices, readings, plants] = await Promise.all([
                api.getDevices(),
                api.getLatestReadings(),
                api.getPlants()
            ]);

            setData({
                devices: devices.devices,
                latestReadings: readings.readings,
                plants: plants.plants
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

    def get_device_24h_data(self, device_code: str) -> Dict:
        return self._request(f'/api/{device_code}/24')

    def decode_hex_data(self, hex_string: str, device_code: str) -> Dict:
        if device_code.startswith('CZ'):  # Cabai (4 sensors)
            return {
                'pH': int(hex_string[0:4], 16) / 100,
                'moisture': int(hex_string[4:8], 16) / 10,
                'ec': int(hex_string[8:12], 16) / 100,
                'temperature': int(hex_string[12:16], 16) / 10
            }
        elif device_code.startswith(('MZ', 'SZ')):  # Melon/Selada (3 sensors)
            return {
                'pH': int(hex_string[0:4], 16) / 100,
                'ec': int(hex_string[4:8], 16) / 100,
                'temperature': int(hex_string[8:12], 16) / 10
            }
        elif device_code.startswith('GZ'):  # Greenhouse (3 sensors)
            return {
                'temperature': int(hex_string[0:4], 16) / 10,
                'humidity': int(hex_string[4:8], 16) / 10,
                'light': int(hex_string[8:12], 16)
            }
        else:
            return {'error': 'Unknown device type'}

# Usage Example
api = GreenhouseAPI()
readings = api.get_latest_readings()

for reading in readings:
    device = reading['zone_code']
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