-- ============================================
-- 1. AGREGAR VALORES AL ENUM (FUERA DE TRANSACCIÓN)
-- ============================================

ALTER TYPE seguros_colectivos.estado_proceso_enum ADD VALUE IF NOT EXISTS 'EN_REVISION';
ALTER TYPE seguros_colectivos.estado_proceso_enum ADD VALUE IF NOT EXISTS 'PENDIENTE_EMISION';
ALTER TYPE seguros_colectivos.estado_proceso_enum ADD VALUE IF NOT EXISTS 'EN_EMISION';
ALTER TYPE seguros_colectivos.estado_proceso_enum ADD VALUE IF NOT EXISTS 'EMITIDA';

ALTER TYPE seguros_colectivos.etapa_enum ADD VALUE 'INFORMACION_RIESGOS';
ALTER TYPE seguros_colectivos.etapa_enum ADD VALUE 'RIESGOS';
ALTER TYPE seguros_colectivos.etapa_enum ADD VALUE 'RESUMEN';


-- ============================================
-- 2. MIGRACIÓN PRINCIPAL
-- ============================================

BEGIN;

-- =========================
-- EXTENSION PARA BUSQUEDA
-- =========================
CREATE EXTENSION IF NOT EXISTS unaccent;


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
-- =========================

CREATE OR REPLACE FUNCTION seguros_colectivos.fn_normalizar_texto(p_texto text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
    SELECT upper(unaccent(coalesce(p_texto, '')));
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
    ON poliza (intermediario_clave, fecha_creacion DESC);


-- Insert data in tipo_adjunto
INSERT INTO seguros_colectivos.tipo_adjunto (tipo, descripcion) 
VALUES ('habeasData', 'habeas data personas asociadas a la póliza para emitir');

-- =========================
-- Ajustes tabla poliza_preguntas
-- =========================

-- 1. Eliminar la columna 'valor'
ALTER TABLE seguros_colectivos.poliza_preguntas DROP COLUMN valor;

-- 2. Renombrar 'valor_texto' a 'respuesta'
ALTER TABLE seguros_colectivos.poliza_preguntas RENAME COLUMN valor_texto TO respuesta;

-- 3. Agregar la columna para el detalle de la respuesta
ALTER TABLE seguros_colectivos.poliza_preguntas ADD COLUMN descripcion_respuesta varchar;



COMMIT;





