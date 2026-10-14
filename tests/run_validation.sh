#!/bin/bash
mkdir -p tests/results
OUT="tests/results/validation_$(date +%F_%H%M).txt"
docker compose exec -T sqlserver bash -c '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -N -b -W -s " | " -i /tests/validate.sql' | tee "$OUT"
exit "${PIPESTATUS[0]}"