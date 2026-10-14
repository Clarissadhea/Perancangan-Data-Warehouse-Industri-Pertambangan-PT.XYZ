SET NOCOUNT ON;
GO
-- ===== 1. SKEMA: 14 tabel =====
SELECT 'schema_tables_14' AS test,
  CASE WHEN COUNT(*)=14 THEN 'PASS' ELSE 'FAIL' END AS hasil, COUNT(*) AS nilai
FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
WHERE s.name IN ('dim','fact','staging');

-- ===== 2. JUMLAH BARIS sesuai README =====
SELECT 'DimTime' AS test, CASE WHEN COUNT(*)=830 THEN 'PASS' ELSE 'FAIL' END AS hasil, COUNT(*) AS nilai FROM dim.DimTime
UNION ALL SELECT 'DimSite', CASE WHEN COUNT(*)=1747 THEN 'PASS' ELSE 'FAIL' END, COUNT(*) FROM dim.DimSite
UNION ALL SELECT 'DimEquipment', CASE WHEN COUNT(*)=6 THEN 'PASS' ELSE 'FAIL' END, COUNT(*) FROM dim.DimEquipment
UNION ALL SELECT 'DimMaterial', CASE WHEN COUNT(*)=5 THEN 'PASS' ELSE 'FAIL' END, COUNT(*) FROM dim.DimMaterial
UNION ALL SELECT 'DimEmployee', CASE WHEN COUNT(*)=10 THEN 'PASS' ELSE 'FAIL' END, COUNT(*) FROM dim.DimEmployee
UNION ALL SELECT 'DimShift', CASE WHEN COUNT(*)=3 THEN 'PASS' ELSE 'FAIL' END, COUNT(*) FROM dim.DimShift
UNION ALL SELECT 'DimProject', CASE WHEN COUNT(*)=50 THEN 'PASS' ELSE 'FAIL' END, COUNT(*) FROM dim.DimProject
UNION ALL SELECT 'DimAccount', CASE WHEN COUNT(*)=30 THEN 'PASS' ELSE 'FAIL' END, COUNT(*) FROM dim.DimAccount
UNION ALL SELECT 'FactEquipmentUsage', CASE WHEN COUNT(*)=236892 THEN 'PASS' ELSE 'FAIL' END, COUNT(*) FROM fact.FactEquipmentUsage
UNION ALL SELECT 'FactProduction', CASE WHEN COUNT(*)=2261 THEN 'PASS' ELSE 'FAIL' END, COUNT(*) FROM fact.FactProduction
UNION ALL SELECT 'FactFinancialTransaction', CASE WHEN COUNT(*)=115901 THEN 'PASS' ELSE 'FAIL' END, COUNT(*) FROM fact.FactFinancialTransaction;

-- ===== 3. INTEGRITAS: 0 orphan =====
SELECT 'orphan_equip_time' AS test, CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END AS hasil, COUNT(*) AS nilai
FROM fact.FactEquipmentUsage f LEFT JOIN dim.DimTime d ON f.time_key=d.time_key WHERE d.time_key IS NULL
UNION ALL SELECT 'orphan_equip_site', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM fact.FactEquipmentUsage f LEFT JOIN dim.DimSite d ON f.site_key=d.site_key WHERE d.site_key IS NULL
UNION ALL SELECT 'orphan_equip_equipment', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM fact.FactEquipmentUsage f LEFT JOIN dim.DimEquipment d ON f.equipment_key=d.equipment_key WHERE d.equipment_key IS NULL
UNION ALL SELECT 'orphan_prod_time', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM fact.FactProduction f LEFT JOIN dim.DimTime d ON f.time_key=d.time_key WHERE d.time_key IS NULL
UNION ALL SELECT 'orphan_prod_site', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM fact.FactProduction f LEFT JOIN dim.DimSite d ON f.site_key=d.site_key WHERE d.site_key IS NULL
UNION ALL SELECT 'orphan_prod_material', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM fact.FactProduction f LEFT JOIN dim.DimMaterial d ON f.material_key=d.material_key WHERE d.material_key IS NULL
UNION ALL SELECT 'orphan_prod_employee', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM fact.FactProduction f LEFT JOIN dim.DimEmployee d ON f.employee_key=d.employee_key WHERE d.employee_key IS NULL
UNION ALL SELECT 'orphan_prod_shift', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM fact.FactProduction f LEFT JOIN dim.DimShift d ON f.shift_key=d.shift_key WHERE d.shift_key IS NULL
UNION ALL SELECT 'orphan_fin_time', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM fact.FactFinancialTransaction f LEFT JOIN dim.DimTime d ON f.time_key=d.time_key WHERE d.time_key IS NULL
UNION ALL SELECT 'orphan_fin_site', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM fact.FactFinancialTransaction f LEFT JOIN dim.DimSite d ON f.site_key=d.site_key WHERE d.site_key IS NULL
UNION ALL SELECT 'orphan_fin_project', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM fact.FactFinancialTransaction f LEFT JOIN dim.DimProject d ON f.project_key=d.project_key WHERE d.project_key IS NULL
UNION ALL SELECT 'orphan_fin_account', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM fact.FactFinancialTransaction f LEFT JOIN dim.DimAccount d ON f.account_key=d.account_key WHERE d.account_key IS NULL;

-- ===== 4. DUPLIKASI surrogate/business key dimensi kecil =====
SELECT 'dup_DimMaterial_id' AS test, CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END AS hasil, COUNT(*) AS nilai
FROM (SELECT material_id FROM dim.DimMaterial GROUP BY material_id HAVING COUNT(*)>1) x
UNION ALL SELECT 'dup_DimShift_id', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM (SELECT shift_id FROM dim.DimShift GROUP BY shift_id HAVING COUNT(*)>1) x
UNION ALL SELECT 'dup_DimEmployee_id', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM (SELECT employee_id FROM dim.DimEmployee GROUP BY employee_id HAVING COUNT(*)>1) x;

-- ===== 5. RENTANG NILAI =====
SELECT 'range_operating_hours_nonneg' AS test, CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END AS hasil, COUNT(*) AS nilai
FROM fact.FactEquipmentUsage WHERE operating_hours<0 OR downtime_hours<0
UNION ALL SELECT 'range_efficiency_0_1', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM fact.FactEquipmentUsage WHERE efficiency_ratio<0 OR efficiency_ratio>1
UNION ALL SELECT 'range_prod_volume_nonneg', CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END, COUNT(*)
FROM fact.FactProduction WHERE produced_volume<0 OR unit_cost<0;

-- ===== 6. AGREGAT (angka README = teks tetap, lihat RUNBOOK) =====
SELECT 'INFO_efisiensi_persen' AS metrik,
  CAST(ROUND(AVG(efficiency_ratio)*100,2) AS DECIMAL(6,2)) AS hasil_kita,
  CAST(95.66 AS DECIMAL(6,2)) AS angka_readme,
  CASE WHEN ABS(AVG(efficiency_ratio)*100-95.66) <= 0.5 THEN 'PASS (toleransi 0.5)' ELSE 'FAIL' END AS status
FROM fact.FactEquipmentUsage;

SELECT 'INFO_' + m.material_type AS metrik,
  SUM(f.produced_volume) AS hasil_kita,
  CASE m.material_type WHEN 'Metal' THEN 434721 ELSE 112687 END AS angka_readme,
  'INFO: angka README = teks tetap, tidak ada query sumber' AS status
FROM fact.FactProduction f
JOIN dim.DimMaterial m ON m.material_key = f.material_key
GROUP BY m.material_type;
GO