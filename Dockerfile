# Imagen local que simula Aurora PostgreSQL con la extensión pg_cron.
# Solo para desarrollo: en Aurora pg_cron se habilita por parameter group.
FROM postgres:15

RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-15-cron \
 && rm -rf /var/lib/apt/lists/*
