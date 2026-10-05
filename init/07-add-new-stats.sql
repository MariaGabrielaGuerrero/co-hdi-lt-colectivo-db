-- =====================================================================
-- 07-add-new-stats.sql
-- ACCIÓN: * Agrega a estado_riesgo los valores REINTENTO, PENDIENTE-TARIFA
--           y REINTENTO-TARIFA.
--         * Agrega a estado_proceso_enum los valores NOVEDAD y PENDIENTE.
--         * Agrega a riesgo_services_log la columna codigo (varchar, nullable).
-- EJECUCIÓN: Script completo. Re-ejecutable.
--            Los ALTER TYPE ... ADD VALUE van sin BEGIN/COMMIT porque un
--            valor nuevo de enum no se puede usar en la misma transacción.
-- REQUISITO: Ejecutar después de 06-add-status-riesgo.sql.
-- =====================================================================

ALTER TYPE seguros_colectivos.estado_riesgo ADD VALUE IF NOT EXISTS 'REINTENTO';
ALTER TYPE seguros_colectivos.estado_riesgo ADD VALUE IF NOT EXISTS 'PENDIENTE-TARIFA';
ALTER TYPE seguros_colectivos.estado_riesgo ADD VALUE IF NOT EXISTS 'REINTENTO-TARIFA';

ALTER TYPE seguros_colectivos.estado_proceso_enum ADD VALUE IF NOT EXISTS 'NOVEDAD';
ALTER TYPE seguros_colectivos.estado_proceso_enum ADD VALUE IF NOT EXISTS 'PENDIENTE';

ALTER TABLE seguros_colectivos.riesgo_services_log ADD COLUMN IF NOT EXISTS codigo varchar NULL;
