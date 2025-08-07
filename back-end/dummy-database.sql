-- Tanaman
INSERT INTO plants (name, media_type, description) VALUES
('Cabai', 'Tanah', 'Cabai media tanah polybag'),
('Melon', 'Hidroponik', 'Melon sistem hidroponik'),
('Selada', 'Hidroponik', 'Selada hidroponik NFT');

-- Zona Cabai CZ1–CZ6
INSERT INTO zones (plant_id, zone_code, zone_label, location_description) VALUES
(1, 'CZ1', 'Zona Cabai 1', 'Baris 1'),
(1, 'CZ2', 'Zona Cabai 2', 'Baris 2'),
(1, 'CZ3', 'Zona Cabai 3', 'Baris 3'),
(1, 'CZ4', 'Zona Cabai 4', 'Baris 4'),
(1, 'CZ5', 'Zona Cabai 5', 'Baris 5'),
(1, 'CZ6', 'Zona Cabai 6', 'Baris 6');

-- Zona Melon MZ1–MZ5
INSERT INTO zones (plant_id, zone_code, zone_label, location_description) VALUES
(2, 'MZ1', 'Zona Melon 1', 'Rakit A1'),
(2, 'MZ2', 'Zona Melon 2', 'Rakit A2'),
(2, 'MZ3', 'Zona Melon 3', 'Rakit B1'),
(2, 'MZ4', 'Zona Melon 4', 'Rakit B2'),
(2, 'MZ5', 'Zona Melon 5', 'Rakit B3');

-- Zona Selada HZ1–HZ2
INSERT INTO zones (plant_id, zone_code, zone_label, location_description) VALUES
(3, 'HZ1', 'Zona Selada Awal', 'Sirkulasi Masuk'),
(3, 'HZ2', 'Zona Selada Akhir', 'Sirkulasi Keluar');

-- Zona Greenhouse GZ
INSERT INTO zones (plant_id, zone_code, zone_label, location_description) VALUES
(NULL, 'GZ', 'Zona Greenhouse Umum', '3 titik deteksi');

-- Devices per zona
INSERT INTO devices (dev_eui, zone_id, code, description) VALUES
-- Cabai CZ1–CZ6
('b223515335aa5ead', (SELECT zone_id FROM zones WHERE zone_code='CZ1'), 'CZ1', 'Device Cabai Zona 1'),
('538c16d906a90fa4', (SELECT zone_id FROM zones WHERE zone_code='CZ2'), 'CZ2', 'Device Cabai Zona 2'),
('86a18a5b971b6746', (SELECT zone_id FROM zones WHERE zone_code='CZ3'), 'CZ3', 'Device Cabai Zona 3'),
('c7bc941f820aea73', (SELECT zone_id FROM zones WHERE zone_code='CZ4'), 'CZ4', 'Device Cabai Zona 4'),
('36629e7a11c07d46', (SELECT zone_id FROM zones WHERE zone_code='CZ5'), 'CZ5', 'Device Cabai Zona 5'),
('191c576e7cf2383c', (SELECT zone_id FROM zones WHERE zone_code='CZ6'), 'CZ6', 'Device Cabai Zona 6'),
-- Melon MZ1–MZ5
('c613377a3c328a44', (SELECT zone_id FROM zones WHERE zone_code='MZ1'), 'MZ1', 'Device Melon Zona 1'),
('6b8006cf9108bddb', (SELECT zone_id FROM zones WHERE zone_code='MZ2'), 'MZ2', 'Device Melon Zona 2'),
('933e9bcfac81c1d5', (SELECT zone_id FROM zones WHERE zone_code='MZ3'), 'MZ3', 'Device Melon Zona 3'),
('b6bbe256acc6c660', (SELECT zone_id FROM zones WHERE zone_code='MZ4'), 'MZ4', 'Device Melon Zona 4'),
('8a5c32df05b07184', (SELECT zone_id FROM zones WHERE zone_code='MZ5'), 'MZ5', 'Device Melon Zona 5'),
-- Selada HZ1–HZ2
('765cd7d4b4d4c378', (SELECT zone_id FROM zones WHERE zone_code='HZ1'), 'HZ1', 'Device Selada Awal'),
('ff2f70e65632d797', (SELECT zone_id FROM zones WHERE zone_code='HZ2'), 'HZ2', 'Device Selada Akhir'),
-- Greenhouse GZ
('d8fda57038ba241f', (SELECT zone_id FROM zones WHERE zone_code='GZ'), 'GZ1', 'Device Greenhouse');

-- Sensors (referensi)
INSERT INTO sensors (sensor_type, unit, sensor_model) VALUES
('pH', '', 'Gravity DF Robot'),
('Soil Moisture', '%', 'Gravity DF Robot'),
('EC', 'mS/cm', 'DFROBOT-EC'),
('Temperature', '°C', 'DS18B20/SHT31-D'),
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

-- Selada (PH, EC, Temp)
DO $$
DECLARE
    dev RECORD;
    sid INT[];
BEGIN
    SELECT ARRAY(SELECT sensor_id FROM sensors WHERE sensor_type IN ('pH', 'EC', 'Temperature')) INTO sid;
    FOR dev IN SELECT device_id FROM devices WHERE code LIKE 'HZ%' LOOP
        FOR i IN 1..3 LOOP
            INSERT INTO device_sensors (device_id, sensor_id, sensor_label, sensor_order)
            VALUES (dev.device_id, sid[i], 'Sensor ' || sid[i], i);
        END LOOP;
    END LOOP;
END$$;

-- Greenhouse (Temp, Light)
DO $$
DECLARE
    dev_id INT;
    temp_id INT;
    light_id INT;
BEGIN
    SELECT device_id INTO dev_id FROM devices WHERE code = 'GZ1';
    SELECT sensor_id INTO temp_id FROM sensors WHERE sensor_type = 'Temperature';
    SELECT sensor_id INTO light_id FROM sensors WHERE sensor_type = 'Light';
    INSERT INTO device_sensors (device_id, sensor_id, sensor_label, sensor_order) VALUES
        (dev_id, temp_id, 'Sensor Suhu Greenhouse', 1),
        (dev_id, light_id, 'Sensor Cahaya Greenhouse', 2);
END$$;

-- -- Dummy sensor readings (1 per device, HEX 4-byte per sensor, 4 sensor = 16 hex chars)
-- -- Misal: PH=0x01F4 (500), Soil=0x02BC (700), EC=0x0064 (100), Temp=0x00C8 (200) => "01F402BC006400C8"
-- INSERT INTO sensor_readings (device_id, encoded_data) VALUES
-- ((SELECT device_id FROM devices WHERE code='CZ1'), '01F4 02BC 0064 00C8'),
-- ((SELECT device_id FROM devices WHERE code='CZ2'), '01E8 02A0 005A 00B4'),
-- ((SELECT device_id FROM devices WHERE code='MZ1'), '01F4 0064 00C8'),
-- ((SELECT device_id FROM devices WHERE code='MZ2'), '01D4 005A 00B4'),
-- ((SELECT device_id FROM devices WHERE code='HZ1'), '01C8 004B 00A0'),
-- ((SELECT device_id FROM devices WHERE code='GZ1'), '00C8 012C');
