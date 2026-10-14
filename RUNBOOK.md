# RUNBOOK - Replikasi Data Warehouse Pertambangan PT XYZ

Repo fork: https://github.com/Clarissadhea/Perancangan-Data-Warehouse-Industri-Pertambangan-PT.XYZ
Branch kerja: `tugas-replikasi`
Lingkungan: Windows 11, Docker Desktop (Compose v5), Python 3.13, SQL Server 2022, LocalStack 3.8.1 (community)

---

## 1. Ringkasan Arsitektur

```
                    +-------------------------------------------+
   CSV (data/) ---> |  S3 (LocalStack)  bucket: ptxyz-raw       |
                    +----------------+--------------------------+
                                     |
   EventBridge rule (rate 1 day) --> Lambda ptxyz-validate (cek jumlah baris CSV)

   CSV --> standalone_etl.py (padanan Glue Job)
              |  staging.* -> dim.* -> fact.*
              v
        SQL Server 2022 (padanan RDS)  DB: PTXYZ_DataWarehouse
              |
   +----------+-----------+-------------+
   |          |           |             |
 Airflow   Grafana     Superset     tests/validate.sql
 (:8080)   (:3000)     (:8088)      (validasi otomatis)
```

Pemetaan layanan yang diminta tugas:

| Diminta | Dipakai | Alasan |
|---|---|---|
| Docker | Docker Desktop + Compose | sesuai tugas |
| S3 | LocalStack S3 | bucket `ptxyz-raw` berisi 3 CSV |
| Lambda | LocalStack Lambda | fungsi `ptxyz-validate` |
| EventBridge | LocalStack Events | rule `ptxyz-daily-validate` -> Lambda |
| RDS | Container SQL Server 2022 | RDS tidak ada di LocalStack community; engine sama dengan README |
| Glue | `standalone_etl.py` + Airflow DAG | Glue tidak ada di LocalStack community; fungsi ETL setara |

## 2. Pemetaan Langkah README -> Perintah

| No | Langkah README | Perintah |
|---|---|---|
| 1 | Siapkan environment | `copy .env.example .env` lalu sesuaikan (`MSSQL_SA_PASSWORD`, `SA_PASSWORD`, `MSSQL_DB`, dst.) |
| 2 | Jalankan database | `docker compose up -d sqlserver db_init` |
| 3 | Buat skema star schema | otomatis oleh `db_init` menjalankan `init-scripts/create-schema.sql` (8 dim, 3 fact, 3 staging) |
| 4 | Jalankan ETL | salin CSV ke `data/raw/Dataset/`, lalu `python standalone_etl.py` |
| 5 | Validasi | `docker compose exec sqlserver bash -c "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P \"$MSSQL_SA_PASSWORD\" -C -N -d PTXYZ_DataWarehouse -i /tests/validate.sql"` |
| 6 | Cloud (S3/Lambda/EventBridge) | `python scripts/setup_localstack.py` |
| 7 | Orkestrasi Airflow | `docker compose up -d --build airflow-webserver airflow-scheduler` (http://localhost:8080) |
| 8 | Dashboard | `docker compose up -d grafana superset` (3000 dan 8088) |
| - | Semua dari nol (DB + ETL + validasi + LocalStack) | `powershell -ExecutionPolicy Bypass -File run_all.ps1 -Fresh` |

Kredensial tidak di-hardcode: semua dibaca dari `.env` (tidak di-commit; hanya `.env.example`).

## 3. Bukti Hasil

### 3.1 Skema
14 tabel terbentuk: `dim.DimTime, DimSite, DimEquipment, DimMaterial, DimEmployee, DimShift, DimProject, DimAccount`; `fact.FactEquipmentUsage, FactProduction, FactFinancialTransaction`; `staging.EquipmentUsage, Production, FinancialTransaction`. Nama tabel, kolom, dan tipe tidak diubah dari DDL repo.

### 3.2 Jumlah baris (hasil = README)

| Tabel | Hasil | README |
|---|---|---|
| DimTime | 830 | 830 |
| DimSite | 1.747 | 1.747 |
| DimEquipment | 6 | 6 |
| DimMaterial | 5 | 5 |
| DimEmployee | 10 | 10 |
| DimShift | 3 | 3 |
| DimProject | 50 | 50 |
| DimAccount | 30 | 30 |
| FactEquipmentUsage | 236.892 | 236.892 |
| FactProduction | 2.261 | 2.261 |
| FactFinancialTransaction | 115.901 | 115.901 |

Staging masing-masing 1.150 baris.

### 3.3 Validasi otomatis (`tests/validate.sql`)
Semua PASS: 14 tabel, 11 cek jumlah baris, 12 cek orphan FK (semuanya 0), 3 cek duplikasi dimensi kecil, 3 cek rentang nilai.

### 3.4 Agregat README
- Efisiensi: hasil 95,60% vs README 95,66% (selisih 0,06; lolos toleransi 0,5).
- Metal 434.721 / Ore 112.687: hasil `SUM(produced_volume)` = 477.837 / 118.363. Angka README ditemukan hanya sebagai **teks tetap** (`configure_dashboards.py:62`, `README.md:409`, `docs/README.md:410`); tidak ada query/skrip di repo yang menghitungnya, sehingga tidak ada rumus untuk ditiru. Ditampilkan sebagai INFO, bukan PASS palsu. Data dan logika ETL tidak dimodifikasi untuk memaksa angka cocok.

### 3.5 Cloud (LocalStack)
Output `python scripts/setup_localstack.py`: S3 berisi 3 CSV; rule `ptxyz-daily-validate` dengan target Lambda `ptxyz-validate`; invoke Lambda mengembalikan PASS untuk 3 CSV (1.150 baris masing-masing).

### 3.6 Layanan web
Airflow (8080), Grafana (3000), Superset (8088) berjalan dan dapat diakses.

Screenshot (letakkan di `docs/screenshots/`):
1. `docker compose ps`
2. Output validate.sql
3. UI Airflow
4. Dashboard Grafana (produksi per tipe material)
5. UI Superset
6. Output setup_localstack.py

## 4. Kueri OLAP
Kueri slice, dice, roll-up, drill-down, dan pivot tersedia di `scripts/comprehensive-olap-queries.sql` (bawaan repo). Contoh roll-up:

```sql
SELECT t.year, t.quarter, SUM(f.produced_volume) AS volume
FROM fact.FactProduction f JOIN dim.DimTime t ON t.time_key = f.time_key
GROUP BY ROLLUP (t.year, t.quarter);
```

## 5. Sumber Data
Data contoh disediakan repo (`data/dataset_*.csv`) dan dipakai apa adanya. Tidak ada data sintetis.

## 6. Kendala dan Solusi

| # | Kendala | Solusi |
|---|---|---|
| 1 | Nama DB di README `PTXYZ_DW`, di DDL repo `PTXYZ_DataWarehouse` | DDL tidak diubah (dilarang); dicatat sebagai selisih penamaan dari repo asli |
| 2 | Password hard-coded di compose, Makefile, dan `standalone_etl.py`; tidak cocok dengan `.env` | Semua dibaca dari `.env` (`${MSSQL_SA_PASSWORD}`, `os.getenv`); hanya orkestrasi |
| 3 | `init-db.sh` berakhiran CRLF (clone di Windows) | `db_init` menjalankan `sed 's/\r$//' ... | bash` |
| 4 | ETL mencari `data/raw/Dataset/*.csv`, file ada di `data/` | CSV disalin otomatis oleh `run_all.ps1`; kode ETL tidak diubah |
| 5 | Error emoji `UnicodeEncodeError` di konsol Windows | `PYTHONUTF8=1` |
| 6 | LocalStack `latest` mewajibkan auth token (exit 55) | Pin ke `localstack/localstack:3.8` (community, tanpa token) |
| 7 | RDS dan Glue tidak tersedia di LocalStack community | Padanan: SQL Server container dan `standalone_etl.py`/Airflow |
| 8 | `awslocal`/`aws` gagal (dua instalasi Python: miniconda dan Python313, file association .py) | Setup ditulis ulang dengan boto3 (`scripts/setup_localstack.py`) |
| 9 | Healthcheck LocalStack `unhealthy` (timeout 5 detik) | Kosmetik; endpoint health menunjukkan layanan running |
| 10 | Build Airflow gagal: folder `plugins/` tidak ada | Dibuat `airflow/plugins/.gitkeep` |
| 11 | Build Airflow gagal: DNS container timeout (UDP 53 ke 8.8.8.8 diblokir; ping 8.8.8.8 berhasil; DNS host normal) | DNS Docker Engine diganti ke DNS jaringan (192.168.200.150) |
| 12 | Jumlah baris fact (2.261) hampir 2x staging (1.150); DimSite 1.747 baris untuk 26 nama situs | Perilaku asli ETL repo; hasil identik README sehingga tidak diubah; tetap 0 orphan |
| 13 | Resource LocalStack hilang setelah restart | `python scripts/setup_localstack.py` idempotent, dijalankan ulang |

## 7. Cara Menjalankan Ulang dari Nol
```
copy .env.example .env      (isi password)
powershell -ExecutionPolicy Bypass -File run_all.ps1 -Fresh
docker compose up -d --build airflow-webserver airflow-scheduler grafana superset
```
Catatan: `-Fresh` menjalankan `docker compose down -v` (menghapus volume).