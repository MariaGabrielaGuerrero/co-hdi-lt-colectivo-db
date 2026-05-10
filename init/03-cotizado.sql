ALTER TYPE seguros_colectivos.etapa_enum ADD VALUE 'INFORMACION_RIESGOS';
ALTER TYPE seguros_colectivos.etapa_enum ADD VALUE 'RIESGOS';
ALTER TYPE seguros_colectivos.etapa_enum ADD VALUE 'RESUMEN';

-- =========================
-- ADD data ejemplo para cotizacion 10000, 10001 y 10002
-- SOLO SE EJECUTA EN DEV Y NONPROD
-- =========================

UPDATE seguros_colectivos.poliza
SET estado_proceso = 'COTIZADO'
WHERE cotizacion IN (10000, 10001, 10002);


INSERT INTO seguros_colectivos.riesgo (cotizacion, certificado, fecha, atributos_riesgo)
VALUES 
(10000, 1, CURRENT_TIMESTAMP, '{
    "placa": "ABC-123",
    "marca": "Chevrolet",
    "modelo": 2025,
    "tipo_servicio": "colectivo_urbano",
    "capacidad_pasajeros": 20,
    "coberturas": ["RC_extracontractual", "perdida_total", "asistencia_juridica"],
    "prima": 500000
}'),
(10000, 2, CURRENT_TIMESTAMP, '{
    "placa": "XYZ-789",
    "marca": "Hyundai",
    "modelo": 2024,
    "tipo_servicio": "colectivo_urbano",
    "capacidad_pasajeros": 18,
    "coberturas": ["RC_extracontractual", "perdida_total"],
    "prima": 450000
}'),
(10000, 3, CURRENT_TIMESTAMP, '{
    "placa": "LMN-456",
    "marca": "Mercedes-Benz",
    "modelo": 2026,
    "tipo_servicio": "colectivo_intermunicipal",
    "capacidad_pasajeros": 40,
    "coberturas": ["RC_extracontractual", "perdida_total", "accidente_pasajeros"],
    "prima": 800000
}'),
(10001, 1, CURRENT_TIMESTAMP, '{
    "placa": "DEF-321",
    "marca": "Volkswagen",
    "modelo": 2023,
    "tipo_servicio": "colectivo_urbano",
    "capacidad_pasajeros": 25,
    "coberturas": ["RC_extracontractual", "perdida_total", "asistencia_juridica"],
    "prima": 600000
}'),
(10001, 2, CURRENT_TIMESTAMP, '{
    "placa": "GHI-654",
    "marca": "Renault",
    "modelo": 2024,
    "tipo_servicio": "colectivo_urbano",
    "capacidad_pasajeros": 22,
    "coberturas": ["RC_extracontractual", "perdida_total"],
    "prima": 550000
}'),
(10001, 3, CURRENT_TIMESTAMP, '{
    "placa": "JKL-987",
    "marca": "Scania",
    "modelo": 2025,
    "tipo_servicio": "colectivo_intermunicipal",
    "capacidad_pasajeros": 50,
    "coberturas": ["RC_extracontractual", "perdida_total", "accidente_pasajeros"],
    "prima": 900000
}'),
(10002, 1, CURRENT_TIMESTAMP, '{
    "placa": "MNO-654",
    "marca": "Volvo",
    "modelo": 2024,
    "tipo_servicio": "colectivo_urbano",
    "capacidad_pasajeros": 30,
    "coberturas": ["RC_extracontractual", "perdida_total", "asistencia_juridica"],
    "prima": 700000
}'),
(10002, 2, CURRENT_TIMESTAMP, '{
    "placa": "PQR-321",
    "marca": "Iveco",
    "modelo": 2023,
    "tipo_servicio": "colectivo_urbano",
    "capacidad_pasajeros": 28,
    "coberturas": ["RC_extracontractual", "perdida_total"],
    "prima": 650000
}');