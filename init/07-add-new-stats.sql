ALTER TYPE seguros_colectivos.estado_riesgo ADD VALUE 'REINTENTO';
ALTER TYPE seguros_colectivos.estado_riesgo ADD VALUE 'PENDIENTE-TARIFA';
ALTER TYPE seguros_colectivos.estado_riesgo ADD VALUE 'REINTENTO-TARIFA';


ALTER TYPE seguros_colectivos.estado_proceso_enum ADD VALUE 'NOVEDAD';

ALTER TYPE seguros_colectivos.estado_proceso_enum ADD VALUE 'PENDIENTE';

ALTER TABLE riesgo_services_log ADD COLUMN codigo varchar NULL;
