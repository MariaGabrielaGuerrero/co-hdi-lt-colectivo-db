-- =====================================================================
-- 09-add-siniestros-estados-bpm.sql
-- ACCIÓN: * Agrega a estado_proceso_enum (poliza) los valores ELIMINADO y
--           CASO_BPM.
--         * Agrega a estado_riesgo (riesgo) los valores PENDIENTE_PRETARIFA
--           y REINTENTO_PRETARIFA.
--         * Crea la tabla auto_siniestros (N siniestros por riesgo), con
--           FK a riesgo (cotizacion, codigo_producto, certificado).
--         * Crea fn_eliminar_casos_bpm_vencidos(): pasa a ELIMINADO las
--           pólizas en CASO_BPM cuya fecha_modificacion tenga 30 días o más.
--         * Si pg_cron está instalado, programa la función diariamente
--           (00:05 hora Colombia = 05:05 UTC).
-- EJECUCIÓN: Script completo. Re-ejecutable.
--            Los ALTER TYPE ... ADD VALUE van sin BEGIN/COMMIT porque un
--            valor nuevo de enum no se puede usar en la misma transacción.
-- REQUISITO: Ejecutar después de 08-add-product-all-tables.sql.
-- NOTA pg_cron (Aurora): requiere 'pg_cron' en shared_preload_libraries del
--            parameter group, cron.database_name = 'lt-colectivo-db' y
--            CREATE EXTENSION pg_cron (rds_superuser). Si no está, la
--            función queda creada y se puede invocar desde el backend o un
--            scheduler externo:  SELECT seguros_colectivos.fn_eliminar_casos_bpm_vencidos();
-- =====================================================================

-- =====================================================================
-- 1. NUEVOS VALORES DE ENUM (FUERA DE TRANSACCIÓN)
-- =====================================================================

ALTER TYPE seguros_colectivos.estado_proceso_enum ADD VALUE IF NOT EXISTS 'ELIMINADO';
ALTER TYPE seguros_colectivos.estado_proceso_enum ADD VALUE IF NOT EXISTS 'CASO_BPM';

ALTER TYPE seguros_colectivos.estado_riesgo ADD VALUE IF NOT EXISTS 'PENDIENTE-PRETARIFA';
ALTER TYPE seguros_colectivos.estado_riesgo ADD VALUE IF NOT EXISTS 'REINTENTO-PRETARIFA';

BEGIN;

-- =====================================================================
-- 2. TABLA auto_siniestros
--    Un riesgo puede tener muchos siniestros, por eso la PK es un id
--    generado y no la llave del riesgo.
--    Mapeo JSON -> columna:
--      nombreGarantia     -> nombre_garantia
--      valorReclamado     -> valor_reclamado
--      valorPagado        -> valor_pagado
--      descripcionEstado  -> descripcion_estado
--      fechaAviso         -> fecha_aviso
-- =====================================================================

CREATE TABLE IF NOT EXISTS seguros_colectivos.auto_siniestros (
    id                   bigint GENERATED ALWAYS AS IDENTITY,
    cotizacion           bigint NOT NULL,
    codigo_producto      varchar(10) NOT NULL,
    certificado          integer NOT NULL,
    nombre_garantia      varchar(100),
    valor_reclamado      numeric(18,2),
    valor_pagado         numeric(18,2),
    descripcion_estado   varchar(50),
    fecha_aviso          seguros_colectivos.fecha_hora_colombia,
    fecha_creacion       seguros_colectivos.fecha_hora_colombia NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT auto_siniestros_pk PRIMARY KEY (id),
    CONSTRAINT auto_siniestros_riesgo_fk
        FOREIGN KEY (cotizacion, codigo_producto, certificado)
        REFERENCES seguros_colectivos.riesgo (cotizacion, codigo_producto, certificado)
        ON DELETE CASCADE,
    CONSTRAINT auto_siniestros_valores_ck
        CHECK ((valor_reclamado IS NULL OR valor_reclamado >= 0)
           AND (valor_pagado    IS NULL OR valor_pagado    >= 0))
);

COMMENT ON TABLE seguros_colectivos.auto_siniestros IS
'Histórico de siniestros por riesgo (producto AUTO). N registros por (cotizacion, codigo_producto, certificado).';

-- Índice para la FK (consultas por riesgo y borrado en cascada)
CREATE INDEX IF NOT EXISTS auto_siniestros_riesgo_idx
    ON seguros_colectivos.auto_siniestros (cotizacion, codigo_producto, certificado);

-- =====================================================================
-- 3. FUNCIÓN: CASO_BPM -> ELIMINADO a los 30 días de la última modificación
--    El trigger poliza_fecha_modificacion_trg actualiza fecha_modificacion
--    al hacer el cambio, quedando registrada la fecha de eliminación.
-- =====================================================================

CREATE OR REPLACE FUNCTION seguros_colectivos.fn_eliminar_casos_bpm_vencidos(
    p_dias integer DEFAULT 30
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_total integer;
BEGIN
    UPDATE seguros_colectivos.poliza
       SET estado_proceso = 'ELIMINADO'
     WHERE estado_proceso = 'CASO_BPM'
       AND fecha_modificacion <= CURRENT_TIMESTAMP - make_interval(days => p_dias);

    GET DIAGNOSTICS v_total = ROW_COUNT;
    RETURN v_total;
END;
$$;

COMMENT ON FUNCTION seguros_colectivos.fn_eliminar_casos_bpm_vencidos(integer) IS
'Pasa a ELIMINADO las pólizas en CASO_BPM con fecha_modificacion de hace p_dias (30 por defecto) o más. Retorna la cantidad de pólizas actualizadas.';

-- Índice para que el job no recorra toda la tabla
CREATE INDEX IF NOT EXISTS poliza_estado_fecha_mod_idx
    ON seguros_colectivos.poliza (estado_proceso, fecha_modificacion);

-- =====================================================================
-- 4. PROGRAMACIÓN CON pg_cron (solo si la extensión está instalada)
-- =====================================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Re-ejecutable: elimina el job si ya existe y lo vuelve a crear
        PERFORM cron.unschedule(jobid)
           FROM cron.job
          WHERE jobname = 'eliminar-casos-bpm-vencidos';

        -- pg_cron usa UTC: 05:05 UTC = 00:05 America/Bogota
        PERFORM cron.schedule(
            'eliminar-casos-bpm-vencidos',
            '5 5 * * *',
            'SELECT seguros_colectivos.fn_eliminar_casos_bpm_vencidos()'
        );
        RAISE NOTICE 'Job pg_cron eliminar-casos-bpm-vencidos programado.';
    ELSE
        RAISE NOTICE 'pg_cron no está instalado: ejecutar seguros_colectivos.fn_eliminar_casos_bpm_vencidos() desde un scheduler externo.';
    END IF;
END;
$$;

COMMIT;
