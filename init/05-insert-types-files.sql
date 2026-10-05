-- =====================================================================
-- 05-insert-types-files.sql
-- ACCIÓN: Inserta en el catálogo tipo_adjunto los tipos
--         'solicitudCotizacion' (Formato solicitud de cotización) y
--         'siniestros' (Formato de siniestros). Si ya existen, no los duplica.
-- EJECUCIÓN: Script completo. Re-ejecutable.
-- =====================================================================

INSERT INTO seguros_colectivos.tipo_adjunto (tipo, descripcion)
VALUES ('solicitudCotizacion', 'Formato solicitud de cotización'),
       ('siniestros', 'Formato de siniestros')
ON CONFLICT (tipo) DO NOTHING;
