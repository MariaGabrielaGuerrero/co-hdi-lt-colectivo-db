-- =====================================================================
-- 10-add-intermediario-poliza.sql
-- ACCIÓN: Agrega a seguros_colectivos.poliza la información del
--         intermediario:
--           * datos_intermediario  (jsonb)   -> objeto con la sesión del
--             intermediario que opera la póliza. Estructura esperada:
--               {
--                 "usuario": "cc12345500",
--                 "clave": "4000100",
--                 "app": "COTWEB",
--                 "perfil": "Gestor",
--                 "nombreIntermediario": "DIRECTO HDI SEG COL S.A. SUC. BOGOTA",
--                 "Sucursal": "97",
--                 "nombreUsuario": "Test, Batman (Colombia)",
--                 "mail": "usuario@hdiseguros.com.co",
--                 "producto": "modificacion",
--                 "stick": "2026.10.26 11.38.53.404"
--               }
--             Solo se valida que sea un objeto JSON; las llaves no se
--             fuerzan para no romper si el front agrega/quita campos.
--           * intermediario_cotiza (varchar) -> intermediario que cotiza.
--           * intermediario_emite  (varchar) -> intermediario que emite.
--         Todas las columnas son nullable: las pólizas existentes no se
--         ven afectadas y no se reescribe la tabla.
-- EJECUCIÓN: Script completo, en una sola transacción. Re-ejecutable.
-- REQUISITO: Ejecutar después de 09-add-siniestros-estados-bpm.sql.
-- =====================================================================

BEGIN;

-- =====================================================================
-- 1. NUEVAS COLUMNAS
-- =====================================================================

ALTER TABLE seguros_colectivos.poliza
    ADD COLUMN IF NOT EXISTS datos_intermediario  jsonb,
    ADD COLUMN IF NOT EXISTS intermediario_cotiza varchar,
    ADD COLUMN IF NOT EXISTS intermediario_emite  varchar;

-- =====================================================================
-- 2. VALIDACIÓN: datos_intermediario debe ser un objeto JSON
-- =====================================================================

ALTER TABLE seguros_colectivos.poliza
    DROP CONSTRAINT IF EXISTS poliza_datos_intermediario_ck;
ALTER TABLE seguros_colectivos.poliza
    ADD CONSTRAINT poliza_datos_intermediario_ck
    CHECK (datos_intermediario IS NULL OR jsonb_typeof(datos_intermediario) = 'object');

-- =====================================================================
-- 3. DOCUMENTACIÓN
-- =====================================================================

COMMENT ON COLUMN seguros_colectivos.poliza.datos_intermediario IS
'Información del intermediario/usuario que opera la póliza (usuario, clave, app, perfil, nombreIntermediario, Sucursal, nombreUsuario, mail, producto, stick).';
COMMENT ON COLUMN seguros_colectivos.poliza.intermediario_cotiza IS
'Intermediario que realiza la cotización.';
COMMENT ON COLUMN seguros_colectivos.poliza.intermediario_emite IS
'Intermediario que realiza la emisión.';

COMMIT;
