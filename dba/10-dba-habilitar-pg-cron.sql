-- =====================================================================
-- dba-habilitar-pg-cron.sql
-- EJECUTA: DBA con rol rds_superuser, conectado a la base lt-colectivo-db.
-- ACCIÓN: * Valida que pg_cron esté cargado (shared_preload_libraries) y
--           que cron.database_name apunte a esta base.
--         * Crea la extensión pg_cron.
--         * Programa el job eliminar-casos-bpm-vencidos (diario 00:05
--           hora Colombia = 05:05 UTC), que pasa a ELIMINADO las pólizas
--           en CASO_BPM con 30 días o más sin modificación.
-- PRERREQUISITOS (fuera de SQL, en el DB cluster parameter group):
--         * shared_preload_libraries debe incluir pg_cron
--         * cron.database_name = lt-colectivo-db
--         * Reinicio de la instancia writer después del cambio.
--         * El script 09-add-siniestros-estados-bpm.sql ya aplicado
--           (crea la función seguros_colectivos.fn_eliminar_casos_bpm_vencidos).
-- EJECUCIÓN: Script completo, en una transacción. Re-ejecutable.
--            Si una validación falla, no se aplica ningún cambio.
-- =====================================================================

BEGIN;

-- 1. Validaciones previas
DO $$
DECLARE
    v_preload  text := current_setting('shared_preload_libraries', true);
    v_cron_db  text := current_setting('cron.database_name', true);
BEGIN
    IF v_preload IS NULL OR v_preload NOT ILIKE '%pg_cron%' THEN
        RAISE EXCEPTION 'pg_cron no está en shared_preload_libraries (valor actual: %). Ajustar el DB cluster parameter group y reiniciar la instancia.', coalesce(v_preload, '<vacío>');
    END IF;

    IF v_cron_db IS DISTINCT FROM current_database() THEN
        RAISE EXCEPTION 'cron.database_name es "%" y la base actual es "%". Ajustar cron.database_name = % en el parameter group.', coalesce(v_cron_db, '<vacío>'), current_database(), current_database();
    END IF;

    IF to_regprocedure('seguros_colectivos.fn_eliminar_casos_bpm_vencidos(integer)') IS NULL THEN
        RAISE EXCEPTION 'No existe seguros_colectivos.fn_eliminar_casos_bpm_vencidos(integer). Aplicar primero 09-add-siniestros-estados-bpm.sql.';
    END IF;
END;
$$;

-- 2. Extensión
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 3. Job (re-ejecutable: elimina el existente y lo vuelve a crear)
SELECT cron.unschedule(jobid)
  FROM cron.job
 WHERE jobname = 'eliminar-casos-bpm-vencidos';

SELECT cron.schedule(
    'eliminar-casos-bpm-vencidos',
    '5 5 * * *',  -- UTC: 05:05 UTC = 00:05 America/Bogota
    'SELECT seguros_colectivos.fn_eliminar_casos_bpm_vencidos()'
);

COMMIT;

-- 4. Verificación (adjuntar el resultado al ticket)
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_cron';

SELECT jobid, jobname, schedule, command, database, username, active
  FROM cron.job
 WHERE jobname = 'eliminar-casos-bpm-vencidos';
