-- =====================================================================
-- 01-quote.sql
-- ACCIÓN: Crea la estructura base del módulo de cotizaciones colectivas
--         en el esquema seguros_colectivos:
--           * Dominio fecha_hora_colombia y enums (tipo póliza, estado
--             proceso, etapa, tipo rol).
--           * Catálogo tipo_adjunto.
--           * Secuencias de cotización por tipo de póliza (AUTOS 10000,
--             HOGAR 20000, PYME 30000) y funciones para consultarlas/moverlas.
--           * Tablas: poliza, poliza_preguntas, poliza_adjuntos,
--             poliza_services_log, riesgo, riesgos_roles, riesgo_coberturas,
--             riesgo_deducibles, riesgo_services_log.
--           * Triggers: asignación de cotización, fecha de modificación,
--             asignación consecutiva de certificado y validación de máximo
--             10000 riesgos por póliza.
--           * Índices de consulta.
-- EJECUCIÓN: Script completo, en una sola transacción. Es re-ejecutable
--            (no falla si los objetos ya existen).
-- =====================================================================

BEGIN;

-- Operar la sesión en hora de Colombia.
SET TIME ZONE 'America/Bogota';

CREATE SCHEMA IF NOT EXISTS seguros_colectivos;
SET search_path TO seguros_colectivos, public;

-- =====================================================================
-- TIPOS Y CATÁLOGOS
-- =====================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                    WHERE n.nspname = 'seguros_colectivos' AND t.typname = 'fecha_hora_colombia') THEN
        CREATE DOMAIN seguros_colectivos.fecha_hora_colombia AS timestamptz;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                    WHERE n.nspname = 'seguros_colectivos' AND t.typname = 'tipo_poliza_enum') THEN
        CREATE TYPE seguros_colectivos.tipo_poliza_enum AS ENUM (
            'AUTOS',
            'HOGAR',
            'PYME'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                    WHERE n.nspname = 'seguros_colectivos' AND t.typname = 'estado_proceso_enum') THEN
        CREATE TYPE seguros_colectivos.estado_proceso_enum AS ENUM (
            'COTIZADO',
            'ANALIZANDO',
            'EN_PROCESO',
            'EN_RECONSIDERACION',
            'VENCIDO'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                    WHERE n.nspname = 'seguros_colectivos' AND t.typname = 'etapa_enum') THEN
        CREATE TYPE seguros_colectivos.etapa_enum AS ENUM (
            'INFORMACION_TOMADOR'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                    WHERE n.nspname = 'seguros_colectivos' AND t.typname = 'tipo_rol_enum') THEN
        CREATE TYPE seguros_colectivos.tipo_rol_enum AS ENUM (
            'CONDUCTOR',
            'ASEGURADO',
            'BENEFICIARIO',
            'BENEFICIARIO_ONEROSO'
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN seguros_colectivos.fecha_hora_colombia IS
'Tipo basado en TIMESTAMPTZ. La aplicación y la base deben operar con la zona horaria America/Bogota.';

CREATE TABLE IF NOT EXISTS seguros_colectivos.tipo_adjunto (
    tipo                varchar PRIMARY KEY,
    descripcion         varchar
);

COMMENT ON TABLE seguros_colectivos.tipo_adjunto IS 'Catálogo para poliza_adjuntos.tipo.';

-- =====================================================================
-- SECUENCIAS DE PÓLIZA POR TIPO
-- =====================================================================

--TODO: validar numero de inicio de secuencia con el backend, para que no se repitan cotizaciones entre tipos de póliza.
CREATE SEQUENCE IF NOT EXISTS seguros_colectivos.secuencia_poliza_autos START WITH 10000 INCREMENT BY 1 MINVALUE 10000;
CREATE SEQUENCE IF NOT EXISTS seguros_colectivos.secuencia_poliza_hogar START WITH 20000 INCREMENT BY 1 MINVALUE 20000;
CREATE SEQUENCE IF NOT EXISTS seguros_colectivos.secuencia_poliza_pyme  START WITH 30000 INCREMENT BY 1 MINVALUE 30000;

CREATE OR REPLACE FUNCTION seguros_colectivos.nombre_secuencia_poliza(p_tipo seguros_colectivos.tipo_poliza_enum)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    CASE p_tipo
        WHEN 'AUTOS' THEN RETURN 'seguros_colectivos.secuencia_poliza_autos';
        WHEN 'HOGAR' THEN RETURN 'seguros_colectivos.secuencia_poliza_hogar';
        WHEN 'PYME'  THEN RETURN 'seguros_colectivos.secuencia_poliza_pyme';
        ELSE
            RAISE EXCEPTION 'Tipo de póliza no soportado: %', p_tipo;
    END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION seguros_colectivos.cambiar_secuencia_poliza(
    p_tipo seguros_colectivos.tipo_poliza_enum,
    p_ultimo_numero bigint
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_nombre_secuencia text;
BEGIN
    IF p_ultimo_numero < 1 THEN
        RAISE EXCEPTION 'El último número de secuencia debe ser mayor o igual a 1.';
    END IF;

    v_nombre_secuencia := seguros_colectivos.nombre_secuencia_poliza(p_tipo);

    EXECUTE format(
        'SELECT setval(%L::regclass, %s, true)',
        v_nombre_secuencia,
        p_ultimo_numero
    );
END;
$$;

COMMENT ON FUNCTION seguros_colectivos.cambiar_secuencia_poliza(seguros_colectivos.tipo_poliza_enum, bigint) IS
'Permite al backend mover la secuencia del tipo de póliza indicado. El siguiente INSERT sin cotizacion usará el valor consecutivo.';

-- =====================================================================
-- TABLAS PRINCIPALES
-- =====================================================================

CREATE TABLE IF NOT EXISTS seguros_colectivos.poliza (
    cotizacion                 bigint PRIMARY KEY,
    fecha_creacion             seguros_colectivos.fecha_hora_colombia NOT NULL,
    fecha_modificacion         seguros_colectivos.fecha_hora_colombia NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo                       seguros_colectivos.tipo_poliza_enum NOT NULL,
    documento                  varchar,
    tipo_documento             varchar,
    descripcion_documento      varchar,
    estado_proceso             seguros_colectivos.estado_proceso_enum NOT NULL DEFAULT 'EN_PROCESO',
    estado_interno             varchar,
    etapa                      seguros_colectivos.etapa_enum NOT NULL DEFAULT 'INFORMACION_TOMADOR',
    mensaje_interno            varchar,
    mensaje_externo            varchar,
    intermediario_clave        varchar,
    datos_adicionales          jsonb
);

CREATE TABLE IF NOT EXISTS seguros_colectivos.poliza_preguntas (
    cotizacion                 bigint NOT NULL,
    codigo_iaxis               varchar NOT NULL,
    descripcion                varchar DEFAULT 'caratula',
    valor                      numeric,
    valor_texto                varchar,
    CONSTRAINT poliza_preguntas_pk PRIMARY KEY (cotizacion, codigo_iaxis),
    CONSTRAINT poliza_preguntas_poliza_fk
        FOREIGN KEY (cotizacion)
        REFERENCES seguros_colectivos.poliza (cotizacion)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS seguros_colectivos.poliza_adjuntos (
    cotizacion                 bigint NOT NULL,
    tipo                       varchar NOT NULL,
    id                         bigint NOT NULL,
    url                        varchar,
    nombre                     varchar,
    CONSTRAINT poliza_adjuntos_pk PRIMARY KEY (cotizacion, tipo, id),
    CONSTRAINT poliza_adjuntos_poliza_fk
        FOREIGN KEY (cotizacion)
        REFERENCES seguros_colectivos.poliza (cotizacion)
        ON DELETE CASCADE,
    CONSTRAINT poliza_adjuntos_tipo_fk
        FOREIGN KEY (tipo)
        REFERENCES seguros_colectivos.tipo_adjunto (tipo)
);

CREATE TABLE IF NOT EXISTS seguros_colectivos.poliza_services_log (
    cotizacion                 bigint NOT NULL,
    nombre                     varchar NOT NULL,
    url                        varchar,
    fecha                      seguros_colectivos.fecha_hora_colombia NOT NULL DEFAULT CURRENT_TIMESTAMP,
    request                    jsonb,
    response                   jsonb,
    CONSTRAINT poliza_services_log_pk PRIMARY KEY (cotizacion, nombre),
    CONSTRAINT poliza_services_log_poliza_fk
        FOREIGN KEY (cotizacion)
        REFERENCES seguros_colectivos.poliza (cotizacion)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS seguros_colectivos.riesgo (
    cotizacion                 bigint NOT NULL,
    certificado                integer NOT NULL,
    fecha                      seguros_colectivos.fecha_hora_colombia,
    atributos_riesgo           jsonb,
    CONSTRAINT riesgo_pk PRIMARY KEY (cotizacion, certificado),
    CONSTRAINT riesgo_poliza_fk
        FOREIGN KEY (cotizacion)
        REFERENCES seguros_colectivos.poliza (cotizacion)
        ON DELETE CASCADE,
    CONSTRAINT riesgo_certificado_rango_ck CHECK (certificado BETWEEN 1 AND 10000)
);

CREATE TABLE IF NOT EXISTS seguros_colectivos.riesgos_roles (
    cotizacion                 bigint NOT NULL,
    certificado                integer NOT NULL,
    tipo_rol                   seguros_colectivos.tipo_rol_enum NOT NULL,
    cant_rol                   integer,
    atributos_persona          jsonb,
    CONSTRAINT riesgos_roles_pk PRIMARY KEY (cotizacion, certificado, tipo_rol),
    CONSTRAINT riesgos_roles_riesgo_fk
        FOREIGN KEY (cotizacion, certificado)
        REFERENCES seguros_colectivos.riesgo (cotizacion, certificado)
        ON DELETE CASCADE,
    CONSTRAINT riesgos_roles_cant_rol_ck CHECK (cant_rol IS NULL OR cant_rol >= 0)
);

CREATE TABLE IF NOT EXISTS seguros_colectivos.riesgo_coberturas (
    cotizacion                 bigint NOT NULL,
    certificado                integer NOT NULL,
    garantia_codigo            varchar NOT NULL,
    capital                    numeric,
    prima                      numeric,
    impuesto                   numeric,
    CONSTRAINT riesgo_coberturas_pk PRIMARY KEY (cotizacion, certificado, garantia_codigo),
    CONSTRAINT riesgo_coberturas_riesgo_fk
        FOREIGN KEY (cotizacion, certificado)
        REFERENCES seguros_colectivos.riesgo (cotizacion, certificado)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS seguros_colectivos.riesgo_deducibles (
    cotizacion                 bigint NOT NULL,
    certificado                integer NOT NULL,
    garantia_codigo            varchar NOT NULL,
    tipo_deducible             varchar,
    tipo_valor                 varchar,
    tipo_valor_minimo          varchar,
    valor_minimo               varchar,
    CONSTRAINT riesgo_deducibles_pk PRIMARY KEY (cotizacion, certificado, garantia_codigo),
    CONSTRAINT riesgo_deducibles_riesgo_fk
        FOREIGN KEY (cotizacion, certificado)
        REFERENCES seguros_colectivos.riesgo (cotizacion, certificado)
        ON DELETE CASCADE
);

-- La PK de esta tabla se amplía a (cotizacion, certificado, nombre) en 06-add-status-riesgo.sql
CREATE TABLE IF NOT EXISTS seguros_colectivos.riesgo_services_log (
    cotizacion                 bigint NOT NULL,
    certificado                integer NOT NULL,
    nombre                     varchar NOT NULL,
    url                        varchar,
    fecha                      seguros_colectivos.fecha_hora_colombia NOT NULL DEFAULT CURRENT_TIMESTAMP,
    request                    jsonb,
    response                   jsonb,
    CONSTRAINT riesgo_services_log_pk PRIMARY KEY (cotizacion, nombre),
    CONSTRAINT fk_riesgo_services_log_riesgo
        FOREIGN KEY (cotizacion, certificado)
        REFERENCES seguros_colectivos.riesgo (cotizacion, certificado)
        ON DELETE CASCADE
);

-- =====================================================================
-- TRIGGERS Y FUNCIONES DE NEGOCIO
-- (las llamadas internas van calificadas con el esquema para que funcionen
--  aunque la sesión de la aplicación no tenga seguros_colectivos en su search_path)
-- =====================================================================

CREATE OR REPLACE FUNCTION seguros_colectivos.trg_poliza_asignar_cotizacion()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_nombre_secuencia text;
BEGIN
    IF NEW.tipo IS NULL THEN
        RAISE EXCEPTION 'La póliza requiere tipo para asignar la cotizacion.';
    END IF;

    v_nombre_secuencia := seguros_colectivos.nombre_secuencia_poliza(NEW.tipo);

    IF NEW.cotizacion IS NULL THEN
        EXECUTE format(
            'SELECT nextval(%L::regclass)',
            v_nombre_secuencia
        )
        INTO NEW.cotizacion;
    ELSE
        EXECUTE format(
            'SELECT setval(%L::regclass, %s, true)',
            v_nombre_secuencia,
            NEW.cotizacion
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS poliza_asignar_cotizacion_trg ON seguros_colectivos.poliza;
CREATE TRIGGER poliza_asignar_cotizacion_trg
BEFORE INSERT ON seguros_colectivos.poliza
FOR EACH ROW
EXECUTE FUNCTION seguros_colectivos.trg_poliza_asignar_cotizacion();

CREATE OR REPLACE FUNCTION seguros_colectivos.trg_poliza_fecha_modificacion()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.fecha_modificacion := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS poliza_fecha_modificacion_trg ON seguros_colectivos.poliza;
CREATE TRIGGER poliza_fecha_modificacion_trg
BEFORE UPDATE ON seguros_colectivos.poliza
FOR EACH ROW
EXECUTE FUNCTION seguros_colectivos.trg_poliza_fecha_modificacion();

CREATE OR REPLACE FUNCTION seguros_colectivos.trg_riesgo_asignar_certificado()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_siguiente integer;
BEGIN
    PERFORM 1
      FROM seguros_colectivos.poliza
     WHERE cotizacion = NEW.cotizacion
     FOR UPDATE;

    SELECT COALESCE(MAX(r.certificado), 0) + 1
      INTO v_siguiente
      FROM seguros_colectivos.riesgo r
     WHERE r.cotizacion = NEW.cotizacion;

    IF NEW.certificado IS NULL THEN
        NEW.certificado := v_siguiente;
    ELSIF NEW.certificado <> v_siguiente THEN
        RAISE EXCEPTION
            'El certificado para la póliza % debe ser % y sin saltos. Valor recibido: %.',
            NEW.cotizacion,
            v_siguiente,
            NEW.certificado;
    END IF;

    IF NEW.certificado < 1 OR NEW.certificado > 10000 THEN
        RAISE EXCEPTION 'El certificado debe estar entre 1 y 10000. Valor recibido: %.', NEW.certificado;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS riesgo_asignar_certificado_trg ON seguros_colectivos.riesgo;
CREATE TRIGGER riesgo_asignar_certificado_trg
BEFORE INSERT ON seguros_colectivos.riesgo
FOR EACH ROW
EXECUTE FUNCTION seguros_colectivos.trg_riesgo_asignar_certificado();

CREATE OR REPLACE FUNCTION seguros_colectivos.validar_riesgos_poliza(p_poliza_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_riesgos INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_total_riesgos
    FROM seguros_colectivos.riesgo
    WHERE cotizacion = p_poliza_id;

    IF v_total_riesgos > 10000 THEN
        RAISE EXCEPTION
            'La póliza % debe tener maximo 10000 riesgos. Actualmente tiene %',
            p_poliza_id, v_total_riesgos;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION seguros_colectivos.trg_validar_riesgos_poliza()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM seguros_colectivos.validar_riesgos_poliza(OLD.cotizacion);
        RETURN NULL;
    END IF;

    PERFORM seguros_colectivos.validar_riesgos_poliza(NEW.cotizacion);

    IF TG_OP = 'UPDATE' AND OLD.cotizacion IS DISTINCT FROM NEW.cotizacion THEN
        PERFORM seguros_colectivos.validar_riesgos_poliza(OLD.cotizacion);
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS riesgo_validar_rangos_y_secuencia_trg ON seguros_colectivos.riesgo;
CREATE CONSTRAINT TRIGGER riesgo_validar_rangos_y_secuencia_trg
AFTER UPDATE OR DELETE ON seguros_colectivos.riesgo
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION seguros_colectivos.trg_validar_riesgos_poliza();

-- =====================================================================
-- ÍNDICES
-- =====================================================================

CREATE INDEX IF NOT EXISTS poliza_tipo_idx ON seguros_colectivos.poliza (tipo);
CREATE INDEX IF NOT EXISTS poliza_estado_proceso_idx ON seguros_colectivos.poliza (estado_proceso);
CREATE INDEX IF NOT EXISTS riesgo_fecha_idx ON seguros_colectivos.riesgo (fecha);
CREATE INDEX IF NOT EXISTS poliza_services_log_fecha_idx ON seguros_colectivos.poliza_services_log (fecha);
CREATE INDEX IF NOT EXISTS riesgo_services_log_fecha_idx ON seguros_colectivos.riesgo_services_log (fecha);

COMMIT;
