-- =====================================================================
-- 02-dashboard.sql
-- ACCIÓN: Ajustes para el dashboard de cotizaciones:
--           * Agrega estados a estado_proceso_enum (EN_REVISION,
--             PENDIENTE_EMISION, EN_EMISION, EMITIDA) y etapas a etapa_enum
--             (INFORMACION_RIESGOS, RIESGOS, RESUMEN).
--           * Instala la extensión unaccent (búsqueda sin tildes).
--           * Agrega a poliza: numero_poliza, nombre_completo,
--             fecha_inicio_vigencia. Agrega a riesgo: prima_riesgo.
--           * Crea fn_normalizar_texto y fn_dashboard_tab (clasifica la
--             póliza en EMITIDAS / PROCESO_EMISION / COTIZACION).
--           * Crea índice poliza (intermediario_clave, fecha_creacion DESC).
--           * Inserta el tipo de adjunto 'habeasData'.
--           * poliza_preguntas: elimina 'valor', renombra 'valor_texto' a
--             'respuesta' y agrega 'descripcion_respuesta'.
-- EJECUCIÓN: Script completo. Re-ejecutable.
-- REQUISITO: Ejecutar después de 01-quote.sql. En Aurora, el usuario debe
--            tener rds_superuser (o la extensión unaccent ya instalada).
-- =====================================================================

-- ============================================
-- 1. AGREGAR VALORES A LOS ENUM (FUERA DE TRANSACCIÓN)
--    Un valor nuevo de enum no puede usarse dentro de la misma transacción
--    que lo crea, por eso va antes del BEGIN.
-- ============================================

ALTER TYPE seguros_colectivos.estado_proceso_enum ADD VALUE IF NOT EXISTS 'EN_REVISION';
ALTER TYPE seguros_colectivos.estado_proceso_enum ADD VALUE IF NOT EXISTS 'PENDIENTE_EMISION';
ALTER TYPE seguros_colectivos.estado_proceso_enum ADD VALUE IF NOT EXISTS 'EN_EMISION';
ALTER TYPE seguros_colectivos.estado_proceso_enum ADD VALUE IF NOT EXISTS 'EMITIDA';

ALTER TYPE seguros_colectivos.etapa_enum ADD VALUE IF NOT EXISTS 'INFORMACION_RIESGOS';
ALTER TYPE seguros_colectivos.etapa_enum ADD VALUE IF NOT EXISTS 'RIESGOS';
ALTER TYPE seguros_colectivos.etapa_enum ADD VALUE IF NOT EXISTS 'RESUMEN';


-- ============================================
-- 2. MIGRACIÓN PRINCIPAL
-- ============================================

BEGIN;

-- =========================
-- EXTENSION PARA BUSQUEDA
-- =========================
CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


-- =========================
-- COLUMNAS NUEVAS EN POLIZA
-- =========================

ALTER TABLE seguros_colectivos.poliza
    ADD COLUMN IF NOT EXISTS numero_poliza varchar(50);

ALTER TABLE seguros_colectivos.poliza
    ADD COLUMN IF NOT EXISTS nombre_completo varchar(255);

ALTER TABLE seguros_colectivos.poliza
    ADD COLUMN IF NOT EXISTS fecha_inicio_vigencia seguros_colectivos.fecha_hora_colombia;


-- =========================
-- COLUMNA EN RIESGO
-- =========================

ALTER TABLE seguros_colectivos.riesgo
    ADD COLUMN IF NOT EXISTS prima_riesgo numeric(18,2);


-- =========================
-- FUNCION NORMALIZACION TEXTO
-- (unaccent calificado con public para no depender del search_path)
-- =========================

CREATE OR REPLACE FUNCTION seguros_colectivos.fn_normalizar_texto(p_texto text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
    SELECT upper(public.unaccent(coalesce(p_texto, '')));
$$;


-- =========================
-- FUNCION CLASIFICACION TAB
-- (IMPORTANTE: USA ::text)
-- =========================

CREATE OR REPLACE FUNCTION seguros_colectivos.fn_dashboard_tab(
    p_estado seguros_colectivos.estado_proceso_enum,
    p_numero_poliza varchar
)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
    SELECT CASE
        WHEN nullif(trim(coalesce(p_numero_poliza, '')), '') IS NOT NULL
             OR p_estado::text = 'EMITIDA'
            THEN 'EMITIDAS'

        WHEN p_estado::text IN (
            'PENDIENTE_EMISION',
            'EN_EMISION'
        )
            THEN 'PROCESO_EMISION'

        WHEN p_estado::text IN (
            'COTIZADO',
            'ANALIZANDO',
            'EN_PROCESO',
            'EN_REVISION',
            'EN_RECONSIDERACION',
            'VENCIDO'
        )
            THEN 'COTIZACION'

        ELSE 'COTIZACION'
    END;
$$;


-- =========================
-- INDICES PARA DASHBOARD
-- =========================

-- Filtro principal por intermediario + orden frecuente por fecha_creacion.
CREATE INDEX IF NOT EXISTS poliza_intermediario_fecha_idx
    ON seguros_colectivos.poliza (intermediario_clave, fecha_creacion DESC);


-- =========================
-- DATOS tipo_adjunto
-- =========================
INSERT INTO seguros_colectivos.tipo_adjunto (tipo, descripcion)
VALUES ('habeasData', 'habeas data personas asociadas a la póliza para emitir')
ON CONFLICT (tipo) DO NOTHING;


-- =========================
-- Ajustes tabla poliza_preguntas
-- =========================

-- 1. Eliminar la columna 'valor'
ALTER TABLE seguros_colectivos.poliza_preguntas DROP COLUMN IF EXISTS valor;

-- 2. Renombrar 'valor_texto' a 'respuesta' (solo si aún no se ha renombrado)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'seguros_colectivos'
                  AND table_name   = 'poliza_preguntas'
                  AND column_name  = 'valor_texto')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'seguros_colectivos'
                  AND table_name   = 'poliza_preguntas'
                  AND column_name  = 'respuesta') THEN
        ALTER TABLE seguros_colectivos.poliza_preguntas RENAME COLUMN valor_texto TO respuesta;
    END IF;
END;
$$;

-- 3. Agregar la columna para el detalle de la respuesta
ALTER TABLE seguros_colectivos.poliza_preguntas ADD COLUMN IF NOT EXISTS descripcion_respuesta varchar;

COMMIT;
