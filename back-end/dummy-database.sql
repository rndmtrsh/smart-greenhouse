-- Tanaman
INSERT INTO plants (name, media_type, description) VALUES
('Cabai', 'Tanah', 'Cabai media tanah polybag'),
('Melon', 'Hidroponik', 'Melon sistem hidroponik'),
('Selada', 'Hidroponik', 'Selada hidroponik NFT');

-- Zona Cabai CZ1–CZ4 (updated to match APP_DEVICES)
INSERT INTO zones (plant_id, zone_code, zone_label, location_description) VALUES
(1, 'CZ1', 'Zona Cabai 1', 'Baris 1'),
(1, 'CZ2', 'Zona Cabai 2', 'Baris 2'),
(1, 'CZ3', 'Zona Cabai 3', 'Baris 3'),
(1, 'CZ4', 'Zona Cabai 4', 'Baris 4');

-- Zona Melon MZ1–MZ2 (updated to match APP_DEVICES)
INSERT INTO zones (plant_id, zone_code, zone_label, location_description) VALUES
(2, 'MZ1', 'Zona Melon 1', 'Rakit A1'),
(2, 'MZ2', 'Zona Melon 2', 'Rakit A2');

-- Zona Selada SZ12, SZ3, SZ4 (updated to match APP_DEVICES)
INSERT INTO zones (plant_id, zone_code, zone_label, location_description) VALUES
(3, 'SZ12', 'Zona Selada 1-2', 'Sirkulasi A-B'),
(3, 'SZ3', 'Zona Selada 3', 'Sirkulasi C'),
(3, 'SZ4', 'Zona Selada 4', 'Sirkulasi D');

-- Zona Greenhouse GZ1 (updated to match APP_DEVICES)
INSERT INTO zones (plant_id, zone_code, zone_label, location_description) VALUES
(NULL, 'GZ1', 'Zona Greenhouse Umum', '3 titik deteksi');

-- Devices per zona (updated: removed dev_eui, using code as identifier)
INSERT INTO devices (zone_id, code, description) VALUES
-- Cabai CZ1–CZ4
((SELECT zone_id FROM zones WHERE zone_code='CZ1'), 'CZ1', 'Device Cabai Zona 1'),
((SELECT zone_id FROM zones WHERE zone_code='CZ2'), 'CZ2', 'Device Cabai Zona 2'),
((SELECT zone_id FROM zones WHERE zone_code='CZ3'), 'CZ3', 'Device Cabai Zona 3'),
((SELECT zone_id FROM zones WHERE zone_code='CZ4'), 'CZ4', 'Device Cabai Zona 4'),
-- Melon MZ1–MZ2
((SELECT zone_id FROM zones WHERE zone_code='MZ1'), 'MZ1', 'Device Melon Zona 1'),
((SELECT zone_id FROM zones WHERE zone_code='MZ2'), 'MZ2', 'Device Melon Zona 2'),
-- Selada SZ12, SZ3, SZ4
((SELECT zone_id FROM zones WHERE zone_code='SZ12'), 'SZ12', 'Device Selada Zona 1-2'),
((SELECT zone_id FROM zones WHERE zone_code='SZ3'), 'SZ3', 'Device Selada Zona 3'),
((SELECT zone_id FROM zones WHERE zone_code='SZ4'), 'SZ4', 'Device Selada Zona 4'),
-- Greenhouse GZ1
((SELECT zone_id FROM zones WHERE zone_code='GZ1'), 'GZ1', 'Device Greenhouse');

-- Sensors (referensi) - added humidity sensor
INSERT INTO sensors (sensor_type, unit, sensor_model) VALUES
('pH', '', 'Gravity DF Robot'),
('Soil Moisture', '%', 'Gravity DF Robot'),
('EC', 'mS/cm', 'DFROBOT-EC'),
('Temperature', '°C', 'DS18B20/SHT31-D'),
('Humidity', '%', 'SHT31-D'),
('Light', 'lux', 'TSL 2561');

-- Device-Sensors mapping per jenis device
-- Cabai (PH, Soil, EC, Temp)
DO $$
DECLARE
    dev RECORD;
    sid INT[];
BEGIN
    SELECT ARRAY(SELECT sensor_id FROM sensors WHERE sensor_type IN ('pH', 'Soil Moisture', 'EC', 'Temperature')) INTO sid;
    FOR dev IN SELECT device_id FROM devices WHERE code LIKE 'CZ%' LOOP
        FOR i IN 1..4 LOOP
            INSERT INTO device_sensors (device_id, sensor_id, sensor_label, sensor_order)
            VALUES (dev.device_id, sid[i], 'Sensor ' || sid[i], i);
        END LOOP;
    END LOOP;
END$$;

-- Melon (PH, EC, Temp)
DO $$
DECLARE
    dev RECORD;
    sid INT[];
BEGIN
    SELECT ARRAY(SELECT sensor_id FROM sensors WHERE sensor_type IN ('pH', 'EC', 'Temperature')) INTO sid;
    FOR dev IN SELECT device_id FROM devices WHERE code LIKE 'MZ%' LOOP
        FOR i IN 1..3 LOOP
            INSERT INTO device_sensors (device_id, sensor_id, sensor_label, sensor_order)
            VALUES (dev.device_id, sid[i], 'Sensor ' || sid[i], i);
        END LOOP;
    END LOOP;
END$$;

-- Selada (PH, EC, Temp) - updated to use SZ%
DO $
DECLARE
    dev RECORD;
    sid INT[];
BEGIN
    SELECT ARRAY(SELECT sensor_id FROM sensors WHERE sensor_type IN ('pH', 'EC', 'Temperature')) INTO sid;
    FOR dev IN SELECT device_id FROM devices WHERE code LIKE 'SZ%' LOOP
        FOR i IN 1..3 LOOP
            INSERT INTO device_sensors (device_id, sensor_id, sensor_label, sensor_order)
            VALUES (dev.device_id, sid[i], 'Sensor ' || sid[i], i);
        END LOOP;
    END LOOP;
END$;

-- Greenhouse (Temp, Humidity, Light) - updated to include humidity sensor
DO $
DECLARE
    dev_id INT;
    temp_id INT;
    humidity_id INT;
    light_id INT;
BEGIN
    SELECT device_id INTO dev_id FROM devices WHERE code = 'GZ1';
    SELECT sensor_id INTO temp_id FROM sensors WHERE sensor_type = 'Temperature';
    SELECT sensor_id INTO humidity_id FROM sensors WHERE sensor_type = 'Humidity';
    SELECT sensor_id INTO light_id FROM sensors WHERE sensor_type = 'Light';
    INSERT INTO device_sensors (device_id, sensor_id, sensor_label, sensor_order) VALUES
        (dev_id, temp_id, 'Sensor Suhu Greenhouse', 1),
        (dev_id, humidity_id, 'Sensor Kelembapan Greenhouse', 2),
        (dev_id, light_id, 'Sensor Cahaya Greenhouse', 3);
END$;

-- Sample sensor readings (optional - for testing)
-- HEX format: 4 characters per sensor reading
-- INSERT INTO sensor_readings (device_id, encoded_data) VALUES
-- ((SELECT device_id FROM devices WHERE code='CZ1'), '01F402BC006400C8'), -- pH=5.00, Moisture=70%, EC=1.00, Temp=20.0°C
-- ((SELECT device_id FROM devices WHERE code='CZ2'), '01E802A0005A00B4'), -- pH=4.88, Moisture=67.2%, EC=0.90, Temp=18.0°C
-- ((SELECT device_id FROM devices WHERE code='MZ1'), '01F4006400C8'),     -- pH=5.00, EC=1.00, Temp=20.0°C
-- ((SELECT device_id FROM devices WHERE code='MZ2'), '01D4005A00B4'),     -- pH=4.68, EC=0.90, Temp=18.0°C
-- ((SELECT device_id FROM devices WHERE code='SZ12'), '01C8004B00A0'),    -- pH=4.56, EC=0.75, Temp=16.0°C
-- ((SELECT device_id FROM devices WHERE code='SZ3'), '01DC005000AA'),     -- pH=4.76, EC=0.80, Temp=17.0°C
-- ((SELECT device_id FROM devices WHERE code='SZ4'), '01E0005500B4'),     -- pH=4.80, EC=0.85, Temp=18.0°C
-- ((SELECT device_id FROM devices WHERE code='GZ1'), '00C801F4012C');     -- Temp=20.0°C, Humidity=50.0%, Light=300 lux