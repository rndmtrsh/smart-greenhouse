-- 1. Tabel tanaman
CREATE TABLE plants (
    plant_id SERIAL PRIMARY KEY, 
    name VARCHAR(50) NOT NULL,
    media_type VARCHAR(20) NOT NULL CHECK (media_type IN ('Tanah', 'Hidroponik')),
    description TEXT
);

-- 2. Tabel zona
CREATE TABLE zones (
    zone_id SERIAL PRIMARY KEY,
    plant_id INT ,
    zone_code VARCHAR(10) UNIQUE NOT NULL,
    zone_label VARCHAR(50),
    location_description TEXT,
    FOREIGN KEY (plant_id) REFERENCES plants(plant_id) ON DELETE CASCADE
);

-- 3. Tabel perangkat IoT
CREATE TABLE devices (
    device_id SERIAL PRIMARY KEY,
    dev_eui VARCHAR(32) UNIQUE NOT NULL,
    zone_id INT NOT NULL,
    code VARCHAR(50),
    description TEXT,
    FOREIGN KEY (zone_id) REFERENCES zones(zone_id) ON DELETE CASCADE
);

-- 4. Tabel jenis sensor
CREATE TABLE sensors (
    sensor_id SERIAL PRIMARY KEY,
    sensor_type VARCHAR(30) NOT NULL,
    unit VARCHAR(15) NOT NULL,
    sensor_model VARCHAR(50)
);

-- 5. Relasi device–sensor (dengan urutan decoding HEX)
CREATE TABLE device_sensors (
    device_sensor_id SERIAL PRIMARY KEY,
    device_id INT NOT NULL,
    sensor_id INT NOT NULL,
    sensor_label VARCHAR(50),
    sensor_order INT NOT NULL CHECK (sensor_order >= 1),
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE,
    FOREIGN KEY (sensor_id) REFERENCES sensors(sensor_id) ON DELETE CASCADE,
    UNIQUE (device_id, sensor_order)
);

-- 6. Pembacaan data dalam HEX per device (gabungan semua sensor per device)
CREATE TABLE sensor_readings (
    reading_id BIGSERIAL PRIMARY KEY,
    device_id INT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    encoded_data CHAR(64) NOT NULL,
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

-- 7. Tabel user sistem
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    pass VARCHAR(255) NOT NULL
);

-- 8. Indexing untuk efisiensi pencarian historis
CREATE INDEX idx_readings_timestamp ON sensor_readings(timestamp);
CREATE INDEX idx_readings_device ON sensor_readings(device_id);
