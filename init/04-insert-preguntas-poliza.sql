-- =====================================================================
-- 04-insert-preguntas-poliza.sql
-- ACCIÓN: Crea la función fn_insertar_preguntas_por_defecto y el trigger
--         tr_crear_preguntas_defecto_poliza_update sobre poliza.
--         Cuando una póliza pasa a estado_proceso = 'EN_REVISION', inserta
--         automáticamente las 17 preguntas por defecto (códigos iAxis) en
--         poliza_preguntas. Si alguna ya existe, no la duplica.
-- EJECUCIÓN: Script completo, en una transacción. Re-ejecutable.
-- REQUISITO: Ejecutar después de 02-dashboard.sql (usa el estado
--            EN_REVISION y la columna respuesta / descripcion_respuesta).
-- =====================================================================

BEGIN;

-- 1. Función que inserta las preguntas por defecto
CREATE OR REPLACE FUNCTION seguros_colectivos.fn_insertar_preguntas_por_defecto()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Insertamos los registros asociados a la nueva cotización (NEW.cotizacion)
    INSERT INTO seguros_colectivos.poliza_preguntas (cotizacion, codigo_iaxis, descripcion, respuesta, descripcion_respuesta) VALUES
    (NEW.cotizacion, '9006', 'Canal', '1', 'Tradicional'),
    (NEW.cotizacion, '7953', '¿Imprimir los pdf con código de barras y con publicidad de medios de pago?', '1', 'Si'),
    (NEW.cotizacion, '7909', 'tomador en PDF', '1', 'Tomador'),
    (NEW.cotizacion, '7912', 'Dias retroactividad anulacion', '60', NULL),
    (NEW.cotizacion, '8292', 'Dias retroactividad emision', '30', NULL),
    (NEW.cotizacion, '9108', 'Grupo empresarial', '1', 'El mismo Tomador'),
    (NEW.cotizacion, '4084', 'Modalidad de cobro', '2', 'Anticipado'),
    (NEW.cotizacion, '4820', '¿Tiene apropiación presupuestal?', '0', 'No'),
    (NEW.cotizacion, '9542', 'Dias vigencia de cotizacion', '30', NULL),
    (NEW.cotizacion, '9543', 'Esquema de renovacion de caratula', '1', 'Prima informada'),
    (NEW.cotizacion, '9544', 'En renovacion actualiza valor asegurado', '1', 'Si'),
    (NEW.cotizacion, '9232', 'Web service', '0', 'No'),
    (NEW.cotizacion, '7869', 'Continuidad', '1', 'Si'),
    (NEW.cotizacion, '9393', 'Tipo de reaseguro', '8', 'Habitual'),
    (NEW.cotizacion, '8941', 'Valor gastos de expedición', '5877', NULL),
    (NEW.cotizacion, '7897', 'Poliza comercializada mediante convenio de uso de red', '0', 'No'),
    (NEW.cotizacion, '4962', 'Ramo Liberty', '20', 'PUAC')
    ON CONFLICT (cotizacion, codigo_iaxis) DO NOTHING;

    RETURN NEW;
END;
$$;


-- 2. Trigger AFTER UPDATE: se dispara solo cuando el estado cambia a EN_REVISION
DROP TRIGGER IF EXISTS tr_crear_preguntas_defecto_poliza_update ON seguros_colectivos.poliza;
CREATE TRIGGER tr_crear_preguntas_defecto_poliza_update
AFTER UPDATE ON seguros_colectivos.poliza
FOR EACH ROW
WHEN (
    -- Condición: El estado nuevo es EN_REVISION
    NEW.estado_proceso = 'EN_REVISION'
    AND
    -- Y el estado anterior era diferente (evita ejecuciones duplicadas)
    OLD.estado_proceso IS DISTINCT FROM NEW.estado_proceso
)
EXECUTE FUNCTION seguros_colectivos.fn_insertar_preguntas_por_defecto();

COMMIT;
