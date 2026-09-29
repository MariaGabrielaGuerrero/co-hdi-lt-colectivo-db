
-- Crear la tabla
CREATE TABLE seguros_colectivos.producto (
    codigo       varchar(10) PRIMARY KEY,
    descripcion  varchar(100) NOT NULL
);

-- Insertamos valores
INSERT INTO seguros_colectivos.producto (codigo, descripcion) VALUES
('900753', 'AUTO'),
('900754', 'HOGAR'),
('900755', 'PYME');

-- Agregar columna codigo_producto a poliza
ALTER TABLE seguros_colectivos.poliza
    ADD COLUMN codigo_producto varchar(10);

-- Migrar datos desde tipo hacia codigo_producto
UPDATE seguros_colectivos.poliza
SET codigo_producto = CASE tipo
    WHEN 'AUTOS' THEN '900753'  -- ahora se mapea a AUTO
    WHEN 'HOGAR' THEN '900754'
    WHEN 'PYME'  THEN '900755'
END;
WHERE tipo IN ('AUTOS','HOGAR','PYME');

-- Asegurar que no queden nulos
ALTER TABLE seguros_colectivos.poliza
    ALTER COLUMN codigo_producto SET NOT NULL;

-- rear la relación con codigo_producto
ALTER TABLE seguros_colectivos.poliza
    ADD CONSTRAINT poliza_producto_fk FOREIGN KEY (codigo_producto)
        REFERENCES seguros_colectivos.producto (codigo);


-- Eliminar las FK dependientes
ALTER TABLE seguros_colectivos.poliza_preguntas DROP CONSTRAINT poliza_preguntas_poliza_fk;
ALTER TABLE seguros_colectivos.poliza_adjuntos DROP CONSTRAINT poliza_adjuntos_poliza_fk;
ALTER TABLE seguros_colectivos.poliza_services_log DROP CONSTRAINT poliza_services_log_poliza_fk;
ALTER TABLE seguros_colectivos.riesgo DROP CONSTRAINT riesgo_poliza_fk;

-- Cambiar la Primary Key
ALTER TABLE seguros_colectivos.poliza
    DROP CONSTRAINT poliza_pkey,
    ADD CONSTRAINT poliza_pk PRIMARY KEY (cotizacion, codigo_producto);

-- Agregar columna codigo_producto en las tablas dependientes:
ALTER TABLE seguros_colectivos.poliza_preguntas ADD COLUMN codigo_producto varchar(10);
ALTER TABLE seguros_colectivos.poliza_adjuntos ADD COLUMN codigo_producto varchar(10);
ALTER TABLE seguros_colectivos.poliza_services_log ADD COLUMN codigo_producto varchar(10);
ALTER TABLE seguros_colectivos.riesgo ADD COLUMN codigo_producto varchar(10);
ALTER TABLE seguros_colectivos.riesgo_services_log  ADD COLUMN codigo_producto varchar(10);


-- functions
CREATE OR REPLACE FUNCTION seguros_colectivos.validar_riesgos_poliza(
p_cotizacion BIGINT,
p_codigo_producto VARCHAR
)
RETURNS VOID AS $$
DECLARE
v_total_riesgos INTEGER;
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
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION seguros_colectivos.trg_validar_riesgos_poliza()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
IF TG_OP = 'DELETE' THEN
PERFORM validar_riesgos_poliza(OLD.cotizacion, OLD.codigo_producto);
RETURN NULL;
END IF;

PERFORM validar_riesgos_poliza(NEW.cotizacion, NEW.codigo_producto);

IF TG_OP = 'UPDATE' AND
(OLD.cotizacion IS DISTINCT FROM NEW.cotizacion
OR OLD.codigo_producto IS DISTINCT FROM NEW.codigo_producto) THEN
PERFORM validar_riesgos_poliza(OLD.cotizacion, OLD.codigo_producto);
END IF;

RETURN NULL;
END;
$$;

-- Migrar datos  a las tablas que no lo tenian 
UPDATE seguros_colectivos.poliza_preguntas pp
SET codigo_producto = p.codigo_producto
FROM seguros_colectivos.poliza p
WHERE pp.cotizacion = p.cotizacion;

UPDATE seguros_colectivos.poliza_adjuntos pa
SET codigo_producto = p.codigo_producto
FROM seguros_colectivos.poliza p
WHERE pa.cotizacion = p.cotizacion;

UPDATE seguros_colectivos.poliza_services_log pl
SET codigo_producto = p.codigo_producto
FROM seguros_colectivos.poliza p
WHERE pl.cotizacion = p.cotizacion;

UPDATE seguros_colectivos.riesgo r
SET codigo_producto = p.codigo_producto
FROM seguros_colectivos.poliza p
WHERE r.cotizacion = p.cotizacion;

UPDATE seguros_colectivos.riesgo_services_log r
SET codigo_producto = p.codigo_producto
FROM seguros_colectivos.poliza p
WHERE r.cotizacion = p.cotizacion;

--Marcar la columna como NOT NULL
ALTER TABLE seguros_colectivos.poliza_preguntas ALTER COLUMN codigo_producto SET NOT NULL;
ALTER TABLE seguros_colectivos.poliza_adjuntos ALTER COLUMN codigo_producto SET NOT NULL;
ALTER TABLE seguros_colectivos.poliza_services_log ALTER COLUMN codigo_producto SET NOT NULL;
ALTER TABLE seguros_colectivos.riesgo ALTER COLUMN codigo_producto SET NOT NULL;
ALTER TABLE seguros_colectivos.riesgo_services_log  ALTER COLUMN codigo_producto SET NOT NULL;

-- Agregar columa a tablas no usadas
ALTER TABLE seguros_colectivos.riesgo_coberturas  ADD COLUMN codigo_producto varchar(10)  NOT NULL;
ALTER TABLE seguros_colectivos.riesgo_deducibles  ADD COLUMN codigo_producto varchar(10)  NOT NULL;
ALTER TABLE seguros_colectivos.riesgos_roles  ADD COLUMN codigo_producto varchar(10)  NOT NULL;

-- Eliminar columna tipo
ALTER TABLE seguros_colectivos.poliza DROP COLUMN tipo;

-- Rename table
ALTER TABLE seguros_colectivos.riesgos_roles RENAME TO riesgo_roles;


-- Recerar PK de las demas tablas
-- poliza_preguntas
ALTER TABLE seguros_colectivos.poliza_preguntas
    DROP CONSTRAINT poliza_preguntas_pk,
    ADD CONSTRAINT poliza_preguntas_pk PRIMARY KEY (cotizacion, codigo_producto, codigo_iaxis);

ALTER TABLE seguros_colectivos.poliza_preguntas
    ADD CONSTRAINT poliza_preguntas_poliza_fk
    FOREIGN KEY (cotizacion, codigo_producto)
    REFERENCES seguros_colectivos.poliza (cotizacion, codigo_producto)
    ON DELETE CASCADE;
--poliza_adjuntos
ALTER TABLE seguros_colectivos.poliza_adjuntos
    DROP CONSTRAINT poliza_adjuntos_pk,
    ADD CONSTRAINT poliza_adjuntos_pk PRIMARY KEY (cotizacion, codigo_producto, tipo, id);

ALTER TABLE seguros_colectivos.poliza_adjuntos
    ADD CONSTRAINT poliza_adjuntos_poliza_fk
    FOREIGN KEY (cotizacion, codigo_producto)
    REFERENCES seguros_colectivos.poliza (cotizacion, codigo_producto)
    ON DELETE CASCADE;
--poliza_services_log
ALTER TABLE seguros_colectivos.poliza_services_log
    DROP CONSTRAINT poliza_services_log_pk,
    ADD CONSTRAINT poliza_services_log_pk PRIMARY KEY (cotizacion, codigo_producto, nombre);

ALTER TABLE seguros_colectivos.poliza_services_log
    ADD CONSTRAINT poliza_services_log_poliza_fk
    FOREIGN KEY (cotizacion, codigo_producto)
    REFERENCES seguros_colectivos.poliza (cotizacion, codigo_producto)
    ON DELETE CASCADE;

--riesgos
ALTER TABLE seguros_colectivos.riesgo_roles DROP CONSTRAINT riesgos_roles_riesgo_fk;
ALTER TABLE seguros_colectivos.riesgo_coberturas DROP CONSTRAINT riesgo_coberturas_riesgo_fk;
ALTER TABLE seguros_colectivos.riesgo_deducibles DROP CONSTRAINT riesgo_deducibles_riesgo_fk;
ALTER TABLE seguros_colectivos.riesgo_services_log DROP CONSTRAINT riesgo_services_log_pk;
-- reisgo
ALTER TABLE seguros_colectivos.riesgo
    DROP CONSTRAINT riesgo_pk,
    ADD CONSTRAINT riesgo_pk PRIMARY KEY (cotizacion, codigo_producto, certificado);
-- riesgo_roles
ALTER TABLE seguros_colectivos.riesgo_roles
    ADD CONSTRAINT riesgo_roles_riesgo_fk
    FOREIGN KEY (cotizacion, codigo_producto, certificado)
    REFERENCES seguros_colectivos.riesgo (cotizacion, codigo_producto, certificado)
    ON DELETE CASCADE;
--riesgo_coberturas
ALTER TABLE seguros_colectivos.riesgo_coberturas
    ADD CONSTRAINT riesgo_coberturas_riesgo_fk
    FOREIGN KEY (cotizacion, codigo_producto, certificado)
    REFERENCES seguros_colectivos.riesgo (cotizacion, codigo_producto, certificado)
    ON DELETE CASCADE;
--riesgo_deducibles
ALTER TABLE seguros_colectivos.riesgo_deducibles
    ADD CONSTRAINT riesgo_deducibles_riesgo_fk
    FOREIGN KEY (cotizacion, codigo_producto, certificado)
    REFERENCES seguros_colectivos.riesgo (cotizacion, codigo_producto, certificado)
    ON DELETE CASCADE;

-- riesgo_services_log
-- 1. Eliminar la PK antigua
ALTER TABLE seguros_colectivos.riesgo_services_log
    DROP CONSTRAINT riesgo_services_log_pk;

-- 2. Crear la nueva PK incluyendo codigo_producto
ALTER TABLE seguros_colectivos.riesgo_services_log
    ADD CONSTRAINT riesgo_services_log_pk
    PRIMARY KEY (cotizacion, codigo_producto, certificado, nombre);

-- 3. Recrear la FK hacia riesgo
ALTER TABLE seguros_colectivos.riesgo_services_log
    DROP CONSTRAINT fk_riesgo_services_log_riesgo,
    ADD CONSTRAINT riesgo_services_log_riesgo_fk
    FOREIGN KEY (cotizacion, codigo_producto, certificado)
    REFERENCES seguros_colectivos.riesgo (cotizacion, codigo_producto, certificado)
    ON DELETE CASCADE;

    
-- riesgo_coberturas
    -- 1. Eliminar las constraints antiguas
ALTER TABLE seguros_colectivos.riesgo_coberturas
    DROP CONSTRAINT riesgo_coberturas_pk,
    DROP CONSTRAINT riesgo_coberturas_riesgo_fk;

-- 2. Crear la nueva PK incluyendo codigo_producto
ALTER TABLE seguros_colectivos.riesgo_coberturas
    ADD CONSTRAINT riesgo_coberturas_pk 
    PRIMARY KEY (cotizacion, codigo_producto, certificado, garantia_codigo);

-- 3. Crear la nueva FK hacia riesgo
ALTER TABLE seguros_colectivos.riesgo_coberturas
    ADD CONSTRAINT riesgo_coberturas_riesgo_fk
    FOREIGN KEY (cotizacion, codigo_producto, certificado)
    REFERENCES seguros_colectivos.riesgo (cotizacion, codigo_producto, certificado)
    ON DELETE CASCADE;

    
--riesgo_deducibles
-- 1. Eliminar las constraints antiguas
ALTER TABLE seguros_colectivos.riesgo_deducibles
    DROP CONSTRAINT riesgo_deducibles_pk,
    DROP CONSTRAINT riesgo_deducibles_riesgo_fk;

-- 2. Crear la nueva PK incluyendo codigo_producto
ALTER TABLE seguros_colectivos.riesgo_deducibles
    ADD CONSTRAINT riesgo_deducibles_pk 
    PRIMARY KEY (cotizacion, codigo_producto, certificado, garantia_codigo);

-- 3. Crear la nueva FK hacia riesgo
ALTER TABLE seguros_colectivos.riesgo_deducibles
    ADD CONSTRAINT riesgo_deducibles_riesgo_fk
    FOREIGN KEY (cotizacion, codigo_producto, certificado)
    REFERENCES seguros_colectivos.riesgo (cotizacion, codigo_producto, certificado)
    ON DELETE CASCADE;


-- riesgo_roles
-- 1. Eliminar las constraints antiguas
ALTER TABLE seguros_colectivos.riesgo_roles
    DROP CONSTRAINT riesgos_roles_pk;

-- 2. Crear la nueva PK incluyendo codigo_producto
ALTER TABLE seguros_colectivos.riesgo_roles
    ADD CONSTRAINT riesgo_roles_pk 
    PRIMARY KEY (cotizacion, codigo_producto, certificado, tipo_rol);


-- Update triggers
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

    v_nombre_secuencia := nombre_secuencia_poliza(NEW.codigo_producto);

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

CREATE OR REPLACE FUNCTION seguros_colectivos.fn_insertar_preguntas_por_defecto()
RETURNS TRIGGER AS $$
BEGIN
    -- Insertamos los registros asociados a la nueva cotización y producto
    INSERT INTO seguros_colectivos.poliza_preguntas (
        cotizacion, codigo_producto, codigo_iaxis, descripcion, respuesta, descripcion_respuesta
    )
    VALUES
        (NEW.cotizacion, NEW.codigo_producto, '9006', 'Canal', 1, 'Tradicional'),
        (NEW.cotizacion, NEW.codigo_producto, '7953', '¿Imprimir los pdf con código de barras y con publicidad de medios de pago?', 1, 'Si'),
        (NEW.cotizacion, NEW.codigo_producto, '7909', 'Tomador en PDF', 1, 'Tomador'),
        (NEW.cotizacion, NEW.codigo_producto, '7912', 'Dias retroactividad anulacion', 60, NULL),
        (NEW.cotizacion, NEW.codigo_producto, '8292', 'Dias retroactividad emision', 30, NULL),
        (NEW.cotizacion, NEW.codigo_producto, '9108', 'Grupo empresarial', 1, 'El mismo Tomador'),
        (NEW.cotizacion, NEW.codigo_producto, '4084', 'Modalidad de cobro', 2, 'Anticipado'),
        (NEW.cotizacion, NEW.codigo_producto, '4820', '¿Tiene apropiación presupuestal?', 0, 'No'),
        (NEW.cotizacion, NEW.codigo_producto, '9542', 'Dias vigencia de cotizacion', 30, NULL),
        (NEW.cotizacion, NEW.codigo_producto, '9543', 'Esquema de renovacion de caratula', 1, 'Prima informada'),
        (NEW.cotizacion, NEW.codigo_producto, '9544', 'En renovacion actualiza valor asegurado', 1, 'Si'),
        (NEW.cotizacion, NEW.codigo_producto, '9232', 'Web service', 0, 'No'),
        (NEW.cotizacion, NEW.codigo_producto, '7869', 'Continuidad', 1, 'Si'),
        (NEW.cotizacion, NEW.codigo_producto, '9393', 'Tipo de reaseguro', 8, 'Habitual'),
        (NEW.cotizacion, NEW.codigo_producto, '8941', 'Valor gastos de expedición', 5877, NULL),
        (NEW.cotizacion, NEW.codigo_producto, '7897', 'Poliza comercializada mediante convenio de uso de red', 0, 'No'),
        (NEW.cotizacion, NEW.codigo_producto, '4962', 'Ramo Liberty', 20, 'PUAC')
    ON CONFLICT (cotizacion, codigo_producto, codigo_iaxis) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

