# Smart Greenhouse API Documentation

Welcome to the **Smart Greenhouse API**.  
This API provides access to greenhouse monitoring and control data, enabling integration with your frontend dashboard or other services.

---

## **Authentication**
All requests must include the API key in the header:

```
X-API-KEY: your_api_key_here
```

Without a valid key, the server will return:

```json
{
  "error": "Unauthorized"
}
```

---

## **Base URL**
When running locally:
```
http://localhost:5000
```

When deployed on a public server (with your domain):
```
https://yourdomain.com
```

---

## **Endpoints**

### 1. **Ping API**
Check if the API is running.

**Endpoint:**
```
GET /api/ping
```

**Response:**
```json
{
  "message": "API is up"
}
```

---

### 2. **Zones**
Retrieve a list of zones in the greenhouse.

**Endpoint:**
```
GET /api/zones/
```

**Response Example:**
```json
[
  {
    "zone_id": 1,
    "plant_id": 3,
    "name": "Zona 1",
    "description": "Hidroponik Lettuce Zone"
  },
  {
    "zone_id": 2,
    "plant_id": 1,
    "name": "Zona 2",
    "description": "Tanah Chili Zone"
  }
]
```

---

### 3. **Latest Sensor Readings**
Retrieve the latest readings from all sensors.

**Endpoint:**
```
GET /api/latest-readings
```

**Response Example:**
```json
[
  {
    "device_id": 1,
    "zone_id": 1,
    "sensor_type": "Temperature",
    "value": 28.3,
    "unit": "°C",
    "timestamp": "2025-08-13T10:20:00"
  },
  {
    "device_id": 1,
    "zone_id": 1,
    "sensor_type": "pH",
    "value": 6.5,
    "unit": "pH",
    "timestamp": "2025-08-13T10:20:00"
  }
]
```

---

### 4. **Sensor Readings by Zone**
Retrieve sensor readings for a specific zone.

**Endpoint:**
```
GET /api/zones/<zone_id>/readings
```

**Example Request:**
```
GET /api/zones/1/readings
```

**Response Example:**
```json
[
  {
    "sensor_type": "Temperature",
    "value": 28.3,
    "unit": "°C",
    "timestamp": "2025-08-13T10:20:00"
  },
  {
    "sensor_type": "Humidity",
    "value": 70,
    "unit": "%",
    "timestamp": "2025-08-13T10:20:00"
  }
]
```

---

### 5. **Add New Sensor Reading**
Add a new reading for a sensor.

**Endpoint:**
```
POST /api/sensor-readings
```

**Request Body:**
```json
{
  "device_id": 1,
  "sensor_id": 5,
  "value": 25.5
}
```

**Response:**
```json
{
  "message": "Sensor reading added successfully."
}
```

---

### 6. **List Plants**
Retrieve a list of plants configured in the greenhouse.

**Endpoint:**
```
GET /api/plants/
```

**Response Example:**
```json
[
  {
    "plant_id": 1,
    "name": "Chili",
    "media_type": "Tanah",
    "description": "Tanaman cabai rawit."
  },
  {
    "plant_id": 2,
    "name": "Lettuce",
    "media_type": "Hidroponik",
    "description": "Selada hijau segar."
  }
]
```

---

## **Error Codes**
| Status Code | Meaning |
|-------------|---------|
| 200 | Success |
| 400 | Bad Request |
| 401 | Unauthorized (Invalid API Key) |
| 404 | Not Found |
| 500 | Internal Server Error |

---

## **Notes**
- All timestamps are in **ISO 8601** format.
- API is secured via **API Key authentication**.
- Use HTTPS for production to secure API communication.

---

**Maintainer:** Smart Greenhouse Project  
**Version:** 1.0.0  
**Last Updated:** 2025-08-13
