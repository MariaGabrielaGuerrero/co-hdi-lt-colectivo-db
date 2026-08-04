CREATE TYPE seguros_colectivos.estado_riesgo AS ENUM ('COMPLETO', 'PENDIENTE', 'ERROR');

ALTER TABLE seguros_colectivos.riesgo
ADD COLUMN estado estado_riesgo DEFAULT 'PENDIENTE';

-- Paso 1: Eliminar la clave primaria existente
ALTER TABLE seguros_colectivos.riesgo_services_log
DROP CONSTRAINT riesgo_services_log_pk;

-- Paso 2: Crear la nueva clave primaria con cotizacion, certificado y nombre
ALTER TABLE seguros_colectivos.riesgo_services_log
ADD CONSTRAINT riesgo_services_log_pk
PRIMARY KEY (cotizacion, certificado, nombre);
