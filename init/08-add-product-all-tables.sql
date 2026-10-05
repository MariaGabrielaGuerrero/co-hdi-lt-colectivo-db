-- =====================================================================
-- 08-add-product-all-tables.sql
-- ACCIÓN: Cambia la llave de negocio de (cotizacion) a
--         (cotizacion, codigo_producto) en todo el modelo:
--           * Crea el catálogo producto (900753 AUTO, 900754 HOGAR, 900755 PYME).
--           * Agrega codigo_producto a poliza y lo llena desde la columna tipo
--             (AUTOS -> 900753, HOGAR -> 900754, PYME -> 900755).
--           * Agrega codigo_producto (NOT NULL) a poliza_preguntas,
--             poliza_adjuntos, poliza_services_log, riesgo, riesgo_services_log,
--             riesgo_coberturas, riesgo_deducibles y riesgo_roles, y lo llena
--             desde poliza.
--           * Renombra la tabla riesgos_roles a riesgo_roles.
--           * Recrea todas las PK y FK incluyendo codigo_producto.
--           * Actualiza funciones/triggers: asignación de cotización por
--             producto, certificado consecutivo por (cotizacion, producto),
--             validación de máximo 10000 riesgos y preguntas por defecto.
--           * Elimina la columna poliza.tipo.
-- EJECUCIÓN: Script completo, en una sola transacción (si algo falla no
--            queda nada a medias). Re-ejecutable.
-- REQUISITO: Ejecutar después de 01 a 07.
-- IMPORTANTE: Después de aplicar este script NO vuelva a ejecutar 01 ni 04:
--             recrearían las versiones anteriores de los triggers (basadas en
--             poliza.tipo) y la tabla riesgos_roles.
--             Desde aquí el backend debe enviar codigo_producto al insertar
--             en poliza (la columna tipo deja de existir).
-- =====================================================================

BEGIN;

-- El trigger de validación de riesgo es DEFERRABLE INITIALLY DEFERRED: al hacer
-- UPDATE sobre riesgo dejaría eventos pendientes hasta el COMMIT y PostgreSQL no
-- permite ALTER TABLE con eventos pendientes. Se fuerza su ejecución inmediata.
SET CONSTRAINTS ALL IMMEDIATE;

-- =====================================================================
-- 1. CATÁLOGO PRODUCTO
-- =====================================================================

CREATE TABLE IF NOT EXISTS seguros_colectivos.producto (
    codigo       varchar(10) PRIMARY KEY,
    descripcion  varchar(100) NOT NULL
);

INSERT INTO seguros_colectivos.producto (codigo, descripcion) VALUES
('900753', 'AUTO'),
('900754', 'HOGAR'),
('900755', 'PYME')
ON CONFLICT (codigo) DO NOTHING;

-- =====================================================================
-- 2. codigo_producto EN POLIZA
-- =====================================================================

ALTER TABLE seguros_colectivos.poliza
    ADD COLUMN IF NOT EXISTS codigo_producto varchar(10);

-- Migrar datos desde tipo (solo si la columna tipo todavía existe)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'seguros_colectivos'
                  AND table_name   = 'poliza'
                  AND column_name  = 'tipo') THEN
        UPDATE seguros_colectivos.poliza
           SET codigo_producto = CASE tipo
                   WHEN 'AUTOS' THEN '900753'
                   WHEN 'HOGAR' THEN '900754'
                   WHEN 'PYME'  THEN '900755'
               END
         WHERE codigo_producto IS NULL;
    END IF;
END;
$$;

ALTER TABLE seguros_colectivos.poliza
    ALTER COLUMN codigo_producto SET NOT NULL;

ALTER TABLE seguros_colectivos.poliza
    DROP CONSTRAINT IF EXISTS poliza_producto_fk;
ALTER TABLE seguros_colectivos.poliza
    ADD CONSTRAINT poliza_producto_fk FOREIGN KEY (codigo_producto)
        REFERENCES seguros_colectivos.producto (codigo);

-- =====================================================================
-- 3. RENOMBRAR riesgos_roles -> riesgo_roles
-- =====================================================================

DO $$
BEGIN
    IF to_regclass('seguros_colectivos.riesgos_roles') IS NOT NULL
       AND to_regclass('seguros_colectivos.riesgo_roles') IS NULL THEN
        ALTER TABLE seguros_colectivos.riesgos_roles RENAME TO riesgo_roles;
    END IF;
END;
$$;

-- =====================================================================
-- 4. codigo_producto EN TABLAS DEPENDIENTES
--    Se agrega nullable, se llena desde poliza y luego se marca NOT NULL
--    (agregarla NOT NULL directo falla si la tabla ya tiene filas).
-- =====================================================================

ALTER TABLE seguros_colectivos.poliza_preguntas    ADD COLUMN IF NOT EXISTS codigo_producto varchar(10);
ALTER TABLE seguros_colectivos.poliza_adjuntos     ADD COLUMN IF NOT EXISTS codigo_producto varchar(10);
ALTER TABLE seguros_colectivos.poliza_services_log ADD COLUMN IF NOT EXISTS codigo_producto varchar(10);
ALTER TABLE seguros_colectivos.riesgo              ADD COLUMN IF NOT EXISTS codigo_producto varchar(10);
ALTER TABLE seguros_colectivos.riesgo_services_log ADD COLUMN IF NOT EXISTS codigo_producto varchar(10);
ALTER TABLE seguros_colectivos.riesgo_coberturas   ADD COLUMN IF NOT EXISTS codigo_producto varchar(10);
ALTER TABLE seguros_colectivos.riesgo_deducibles   ADD COLUMN IF NOT EXISTS codigo_producto varchar(10);
ALTER TABLE seguros_colectivos.riesgo_roles        ADD COLUMN IF NOT EXISTS codigo_producto varchar(10);

UPDATE seguros_colectivos.poliza_preguntas t SET codigo_producto = p.codigo_producto
  FROM seguros_colectivos.poliza p WHERE t.cotizacion = p.cotizacion AND t.codigo_producto IS NULL;
UPDATE seguros_colectivos.poliza_adjuntos t SET codigo_producto = p.codigo_producto
  FROM seguros_colectivos.poliza p WHERE t.cotizacion = p.cotizacion AND t.codigo_producto IS NULL;
UPDATE seguros_colectivos.poliza_services_log t SET codigo_producto = p.codigo_producto
  FROM seguros_colectivos.poliza p WHERE t.cotizacion = p.cotizacion AND t.codigo_producto IS NULL;
UPDATE seguros_colectivos.riesgo t SET codigo_producto = p.codigo_producto
  FROM seguros_colectivos.poliza p WHERE t.cotizacion = p.cotizacion AND t.codigo_producto IS NULL;
UPDATE seguros_colectivos.riesgo_services_log t SET codigo_producto = p.codigo_producto
  FROM seguros_colectivos.poliza p WHERE t.cotizacion = p.cotizacion AND t.codigo_producto IS NULL;
UPDATE seguros_colectivos.riesgo_coberturas t SET codigo_producto = p.codigo_producto
  FROM seguros_colectivos.poliza p WHERE t.cotizacion = p.cotizacion AND t.codigo_producto IS NULL;
UPDATE seguros_colectivos.riesgo_deducibles t SET codigo_producto = p.codigo_producto
  FROM seguros_colectivos.poliza p WHERE t.cotizacion = p.cotizacion AND t.codigo_producto IS NULL;
UPDATE seguros_colectivos.riesgo_roles t SET codigo_producto = p.codigo_producto
  FROM seguros_colectivos.poliza p WHERE t.cotizacion = p.cotizacion AND t.codigo_producto IS NULL;

ALTER TABLE seguros_colectivos.poliza_preguntas    ALTER COLUMN codigo_producto SET NOT NULL;
ALTER TABLE seguros_colectivos.poliza_adjuntos     ALTER COLUMN codigo_producto SET NOT NULL;
ALTER TABLE seguros_colectivos.poliza_services_log ALTER COLUMN codigo_producto SET NOT NULL;
ALTER TABLE seguros_colectivos.riesgo              ALTER COLUMN codigo_producto SET NOT NULL;
ALTER TABLE seguros_colectivos.riesgo_services_log ALTER COLUMN codigo_producto SET NOT NULL;
ALTER TABLE seguros_colectivos.riesgo_coberturas   ALTER COLUMN codigo_producto SET NOT NULL;
ALTER TABLE seguros_colectivos.riesgo_deducibles   ALTER COLUMN codigo_producto SET NOT NULL;
ALTER TABLE seguros_colectivos.riesgo_roles        ALTER COLUMN codigo_producto SET NOT NULL;

-- =====================================================================
-- 5. ELIMINAR TODAS LAS FK (nombres antiguos y nuevos)
--    Deben eliminarse antes de cambiar las PK de las que dependen.
-- =====================================================================

-- Hacia riesgo
ALTER TABLE seguros_colectivos.riesgo_roles        DROP CONSTRAINT IF EXISTS riesgos_roles_riesgo_fk;
ALTER TABLE seguros_colectivos.riesgo_roles        DROP CONSTRAINT IF EXISTS riesgo_roles_riesgo_fk;
ALTER TABLE seguros_colectivos.riesgo_coberturas   DROP CONSTRAINT IF EXISTS riesgo_coberturas_riesgo_fk;
ALTER TABLE seguros_colectivos.riesgo_deducibles   DROP CONSTRAINT IF EXISTS riesgo_deducibles_riesgo_fk;
ALTER TABLE seguros_colectivos.riesgo_services_log DROP CONSTRAINT IF EXISTS fk_riesgo_services_log_riesgo;
ALTER TABLE seguros_colectivos.riesgo_services_log DROP CONSTRAINT IF EXISTS riesgo_services_log_riesgo_fk;

-- Hacia poliza
ALTER TABLE seguros_colectivos.poliza_preguntas    DROP CONSTRAINT IF EXISTS poliza_preguntas_poliza_fk;
ALTER TABLE seguros_colectivos.poliza_adjuntos     DROP CONSTRAINT IF EXISTS poliza_adjuntos_poliza_fk;
ALTER TABLE seguros_colectivos.poliza_services_log DROP CONSTRAINT IF EXISTS poliza_services_log_poliza_fk;
ALTER TABLE seguros_colectivos.riesgo              DROP CONSTRAINT IF EXISTS riesgo_poliza_fk;

-- =====================================================================
-- 6. RECREAR PRIMARY KEYS
-- =====================================================================

ALTER TABLE seguros_colectivos.poliza
    DROP CONSTRAINT IF EXISTS poliza_pkey,
    DROP CONSTRAINT IF EXISTS poliza_pk,
    ADD CONSTRAINT poliza_pk PRIMARY KEY (cotizacion, codigo_producto);

ALTER TABLE seguros_colectivos.poliza_preguntas
    DROP CONSTRAINT IF EXISTS poliza_preguntas_pk,
    ADD CONSTRAINT poliza_preguntas_pk PRIMARY KEY (cotizacion, codigo_producto, codigo_iaxis);

ALTER TABLE seguros_colectivos.poliza_adjuntos
    DROP CONSTRAINT IF EXISTS poliza_adjuntos_pk,
    ADD CONSTRAINT poliza_adjuntos_pk PRIMARY KEY (cotizacion, codigo_producto, tipo, id);

ALTER TABLE seguros_colectivos.poliza_services_log
    DROP CONSTRAINT IF EXISTS poliza_services_log_pk,
    ADD CONSTRAINT poliza_services_log_pk PRIMARY KEY (cotizacion, codigo_producto, nombre);

ALTER TABLE seguros_colectivos.riesgo
    DROP CONSTRAINT IF EXISTS riesgo_pk,
    ADD CONSTRAINT riesgo_pk PRIMARY KEY (cotizacion, codigo_producto, certificado);

ALTER TABLE seguros_colectivos.riesgo_services_log
    DROP CONSTRAINT IF EXISTS riesgo_services_log_pk,
    ADD CONSTRAINT riesgo_services_log_pk PRIMARY KEY (cotizacion, codigo_producto, certificado, nombre);

ALTER TABLE seguros_colectivos.riesgo_coberturas
    DROP CONSTRAINT IF EXISTS riesgo_coberturas_pk,
    ADD CONSTRAINT riesgo_coberturas_pk PRIMARY KEY (cotizacion, codigo_producto, certificado, garantia_codigo);

ALTER TABLE seguros_colectivos.riesgo_deducibles
    DROP CONSTRAINT IF EXISTS riesgo_deducibles_pk,
    ADD CONSTRAINT riesgo_deducibles_pk PRIMARY KEY (cotizacion, codigo_producto, certificado, garantia_codigo);

ALTER TABLE seguros_colectivos.riesgo_roles
    DROP CONSTRAINT IF EXISTS riesgos_roles_pk,
    DROP CONSTRAINT IF EXISTS riesgo_roles_pk,
    ADD CONSTRAINT riesgo_roles_pk PRIMARY KEY (cotizacion, codigo_producto, certificado, tipo_rol);

-- =====================================================================
-- 7. RECREAR FOREIGN KEYS
-- =====================================================================

-- Hacia poliza
ALTER TABLE seguros_colectivos.poliza_preguntas
    ADD CONSTRAINT poliza_preguntas_poliza_fk
    FOREIGN KEY (cotizacion, codigo_producto)
    REFERENCES seguros_colectivos.poliza (cotizacion, codigo_producto)
    ON DELETE CASCADE;

ALTER TABLE seguros_colectivos.poliza_adjuntos
    ADD CONSTRAINT poliza_adjuntos_poliza_fk
    FOREIGN KEY (cotizacion, codigo_producto)
    REFERENCES seguros_colectivos.poliza (cotizacion, codigo_producto)
    ON DELETE CASCADE;

ALTER TABLE seguros_colectivos.poliza_services_log
    ADD CONSTRAINT poliza_services_log_poliza_fk
    FOREIGN KEY (cotizacion, codigo_producto)
    REFERENCES seguros_colectivos.poliza (cotizacion, codigo_producto)
    ON DELETE CASCADE;

ALTER TABLE seguros_colectivos.riesgo
    ADD CONSTRAINT riesgo_poliza_fk
    FOREIGN KEY (cotizacion, codigo_producto)
    REFERENCES seguros_colectivos.poliza (cotizacion, codigo_producto)
    ON DELETE CASCADE;

-- Hacia riesgo
ALTER TABLE seguros_colectivos.riesgo_roles
    ADD CONSTRAINT riesgo_roles_riesgo_fk
    FOREIGN KEY (cotizacion, codigo_producto, certificado)
    REFERENCES seguros_colectivos.riesgo (cotizacion, codigo_producto, certificado)
    ON DELETE CASCADE;

ALTER TABLE seguros_colectivos.riesgo_coberturas
    ADD CONSTRAINT riesgo_coberturas_riesgo_fk
    FOREIGN KEY (cotizacion, codigo_producto, certificado)
    REFERENCES seguros_colectivos.riesgo (cotizacion, codigo_producto, certificado)
    ON DELETE CASCADE;

ALTER TABLE seguros_colectivos.riesgo_deducibles
    ADD CONSTRAINT riesgo_deducibles_riesgo_fk
    FOREIGN KEY (cotizacion, codigo_producto, certificado)
    REFERENCES seguros_colectivos.riesgo (cotizacion, codigo_producto, certificado)
    ON DELETE CASCADE;

ALTER TABLE seguros_colectivos.riesgo_services_log
    ADD CONSTRAINT riesgo_services_log_riesgo_fk
    FOREIGN KEY (cotizacion, codigo_producto, certificado)
    REFERENCES seguros_colectivos.riesgo (cotizacion, codigo_producto, certificado)
    ON DELETE CASCADE;

-- =====================================================================
-- 8. FUNCIONES Y TRIGGERS
-- =====================================================================

-- 8.1 Secuencia por código de producto.
--     Se usa un nombre nuevo (no una sobrecarga de nombre_secuencia_poliza)
--     para no volver ambiguas las llamadas existentes con 'AUTOS'/'HOGAR'/'PYME'.
CREATE OR REPLACE FUNCTION seguros_colectivos.nombre_secuencia_producto(p_codigo_producto varchar)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    CASE p_codigo_producto
        WHEN '900753' THEN RETURN 'seguros_colectivos.secuencia_poliza_autos';
        WHEN '900754' THEN RETURN 'seguros_colectivos.secuencia_poliza_hogar';
        WHEN '900755' THEN RETURN 'seguros_colectivos.secuencia_poliza_pyme';
        ELSE
            RAISE EXCEPTION 'Producto no soportado para asignar cotización: %', p_codigo_producto;
    END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION seguros_colectivos.cambiar_secuencia_producto(
    p_codigo_producto varchar,
    p_ultimo_numero bigint
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_ultimo_numero < 1 THEN
        RAISE EXCEPTION 'El último número de secuencia debe ser mayor o igual a 1.';
    END IF;

    EXECUTE format(
        'SELECT setval(%L::regclass, %s, true)',
        seguros_colectivos.nombre_secuencia_producto(p_codigo_producto),
        p_ultimo_numero
    );
END;
$$;

COMMENT ON FUNCTION seguros_colectivos.cambiar_secuencia_producto(varchar, bigint) IS
'Permite al backend mover la secuencia del producto indicado. El siguiente INSERT sin cotizacion usará el valor consecutivo.';

-- 8.2 Asignación de cotización (BEFORE INSERT en poliza)
CREATE OR REPLACE FUNCTION seguros_colectivos.trg_poliza_asignar_cotizacion()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_nombre_secuencia text;
BEGIN
    IF NEW.codigo_producto IS NULL THEN
        RAISE EXCEPTION 'La póliza requiere producto para asignar la cotización.';
    END IF;

    v_nombre_secuencia := seguros_colectivos.nombre_secuencia_producto(NEW.codigo_producto);

    IF NEW.cotizacion IS NULL THEN
        EXECUTE format('SELECT nextval(%L::regclass)', v_nombre_secuencia)
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

-- 8.3 Certificado consecutivo por (cotizacion, codigo_producto) (BEFORE INSERT en riesgo)
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
       AND codigo_producto = NEW.codigo_producto
     FOR UPDATE;

    SELECT COALESCE(MAX(r.certificado), 0) + 1
      INTO v_siguiente
      FROM seguros_colectivos.riesgo r
     WHERE r.cotizacion = NEW.cotizacion
       AND r.codigo_producto = NEW.codigo_producto;

    IF NEW.certificado IS NULL THEN
        NEW.certificado := v_siguiente;
    ELSIF NEW.certificado <> v_siguiente THEN
        RAISE EXCEPTION
            'El certificado para la póliza %-% debe ser % y sin saltos. Valor recibido: %.',
            NEW.cotizacion, NEW.codigo_producto, v_siguiente, NEW.certificado;
    END IF;

    IF NEW.certificado < 1 OR NEW.certificado > 10000 THEN
        RAISE EXCEPTION 'El certificado debe estar entre 1 y 10000. Valor recibido: %.', NEW.certificado;
    END IF;

    RETURN NEW;
END;
$$;

-- 8.4 Validación de máximo 10000 riesgos por póliza
CREATE OR REPLACE FUNCTION seguros_colectivos.validar_riesgos_poliza(
    p_cotizacion bigint,
    p_codigo_producto varchar
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_riesgos integer;
BEGIN
    SELECT COUNT(*)
      INTO v_total_riesgos
      FROM seguros_colectivos.riesgo
     WHERE cotizacion = p_cotizacion
       AND codigo_producto = p_codigo_producto;

    IF v_total_riesgos > 10000 THEN
        RAISE EXCEPTION
            'La póliza %-% debe tener máximo 10000 riesgos. Actualmente tiene %',
            p_cotizacion, p_codigo_producto, v_total_riesgos;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION seguros_colectivos.trg_validar_riesgos_poliza()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM seguros_colectivos.validar_riesgos_poliza(OLD.cotizacion, OLD.codigo_producto);
        RETURN NULL;
    END IF;

    PERFORM seguros_colectivos.validar_riesgos_poliza(NEW.cotizacion, NEW.codigo_producto);

    IF TG_OP = 'UPDATE' AND
       (OLD.cotizacion IS DISTINCT FROM NEW.cotizacion
        OR OLD.codigo_producto IS DISTINCT FROM NEW.codigo_producto) THEN
        PERFORM seguros_colectivos.validar_riesgos_poliza(OLD.cotizacion, OLD.codigo_producto);
    END IF;

    RETURN NULL;
END;
$$;

-- La versión anterior (solo cotizacion) ya no se usa
DROP FUNCTION IF EXISTS seguros_colectivos.validar_riesgos_poliza(bigint);

-- 8.5 Preguntas por defecto (trigger creado en 04, se dispara al pasar a EN_REVISION)
CREATE OR REPLACE FUNCTION seguros_colectivos.fn_insertar_preguntas_por_defecto()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO seguros_colectivos.poliza_preguntas (
        cotizacion, codigo_producto, codigo_iaxis, descripcion, respuesta, descripcion_respuesta
    )
    VALUES
        (NEW.cotizacion, NEW.codigo_producto, '9006', 'Canal', '1', 'Tradicional'),
        (NEW.cotizacion, NEW.codigo_producto, '7953', '¿Imprimir los pdf con código de barras y con publicidad de medios de pago?', '1', 'Si'),
        (NEW.cotizacion, NEW.codigo_producto, '7909', 'Tomador en PDF', '1', 'Tomador'),
        (NEW.cotizacion, NEW.codigo_producto, '7912', 'Dias retroactividad anulacion', '60', NULL),
        (NEW.cotizacion, NEW.codigo_producto, '8292', 'Dias retroactividad emision', '30', NULL),
        (NEW.cotizacion, NEW.codigo_producto, '9108', 'Grupo empresarial', '1', 'El mismo Tomador'),
        (NEW.cotizacion, NEW.codigo_producto, '4084', 'Modalidad de cobro', '2', 'Anticipado'),
        (NEW.cotizacion, NEW.codigo_producto, '4820', '¿Tiene apropiación presupuestal?', '0', 'No'),
        (NEW.cotizacion, NEW.codigo_producto, '9542', 'Dias vigencia de cotizacion', '30', NULL),
        (NEW.cotizacion, NEW.codigo_producto, '9543', 'Esquema de renovacion de caratula', '1', 'Prima informada'),
        (NEW.cotizacion, NEW.codigo_producto, '9544', 'En renovacion actualiza valor asegurado', '1', 'Si'),
        (NEW.cotizacion, NEW.codigo_producto, '9232', 'Web service', '0', 'No'),
        (NEW.cotizacion, NEW.codigo_producto, '7869', 'Continuidad', '1', 'Si'),
        (NEW.cotizacion, NEW.codigo_producto, '9393', 'Tipo de reaseguro', '8', 'Habitual'),
        (NEW.cotizacion, NEW.codigo_producto, '8941', 'Valor gastos de expedición', '5877', NULL),
        (NEW.cotizacion, NEW.codigo_producto, '7897', 'Poliza comercializada mediante convenio de uso de red', '0', 'No'),
        (NEW.cotizacion, NEW.codigo_producto, '4962', 'Ramo Liberty', '20', 'PUAC')
    ON CONFLICT (cotizacion, codigo_producto, codigo_iaxis) DO NOTHING;

    RETURN NEW;
END;
$$;

-- =====================================================================
-- 9. ELIMINAR COLUMNA tipo DE POLIZA
--    (también elimina el índice poliza_tipo_idx)
-- =====================================================================

ALTER TABLE seguros_colectivos.poliza DROP COLUMN IF EXISTS tipo;

-- Índice para consultas por producto
CREATE INDEX IF NOT EXISTS poliza_codigo_producto_idx
    ON seguros_colectivos.poliza (codigo_producto);

COMMIT;
