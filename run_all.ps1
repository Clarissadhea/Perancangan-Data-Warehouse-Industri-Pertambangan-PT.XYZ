param([switch]$Fresh)
$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

if ($Fresh) { docker compose down -v }

# 1. Env
if (-not (Test-Path .env)) { Copy-Item .env.example .env }

# 2. Salin CSV ke path yang dicari standalone_etl.py
New-Item -ItemType Directory -Force data\raw\Dataset | Out-Null
Copy-Item data\*.csv data\raw\Dataset\ -Force

# 3. Database + skema
docker compose up -d sqlserver db_init
$code = docker wait ptxyz_db_init
if ($code -ne "0") { throw "db_init gagal (exit $code). Cek: docker compose logs db_init" }

# 4. ETL
pip install -q -r requirements.txt
python standalone_etl.py
if ($LASTEXITCODE -ne 0) { throw "ETL gagal" }

# 5. Validasi
docker compose exec sqlserver bash -c "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P \`"`$MSSQL_SA_PASSWORD\`" -C -N -d PTXYZ_DataWarehouse -i /tests/validate.sql"

# 6. LocalStack (S3, Lambda, EventBridge)
docker compose up -d localstack
python -m pip install -q boto3
python scripts\setup_localstack.py
if ($LASTEXITCODE -ne 0) { throw "Setup LocalStack gagal" }