-- =====================================================================
-- 06-add-status-riesgo.sql
-- ACCIÓN: * Crea el enum estado_riesgo (COMPLETO, PENDIENTE, ERROR).
--         * Agrega a riesgo la columna estado (default 'PENDIENTE').
--         * Cambia la PK de riesgo_services_log de (cotizacion, nombre) a
--           (cotizacion, certificado, nombre), para registrar logs por
--           cada certificado.
-- EJECUCIÓN: Script completo, en una transacción. Re-ejecutable.
-- =====================================================================

BEGIN;

-- 1. Enum de estado del riesgo
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                    WHERE n.nspname = 'seguros_colectivos' AND t.typname = 'estado_riesgo') THEN
        CREATE TYPE seguros_colectivos.estado_riesgo AS ENUM ('COMPLETO', 'PENDIENTE', 'ERROR');
    END IF;
END;
$$;

-- 2. Columna estado en riesgo
ALTER TABLE seguros_colectivos.riesgo
    ADD COLUMN IF NOT EXISTS estado seguros_colectivos.estado_riesgo DEFAULT 'PENDIENTE';

-- 3. Nueva PK de riesgo_services_log (solo si todavía no incluye certificado)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint c
          JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
         WHERE c.conrelid = 'seguros_colectivos.riesgo_services_log'::regclass
           AND c.contype  = 'p'
           AND a.attname  = 'certificado'
    ) THEN
        ALTER TABLE seguros_colectivos.riesgo_services_log
            DROP CONSTRAINT IF EXISTS riesgo_services_log_pk;

        ALTER TABLE seguros_colectivos.riesgo_services_log
            ADD CONSTRAINT riesgo_services_log_pk
            PRIMARY KEY (cotizacion, certificado, nombre);
    END IF;
END;
$$;

COMMIT;
