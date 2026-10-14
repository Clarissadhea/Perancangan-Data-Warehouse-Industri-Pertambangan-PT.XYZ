SET NOCOUNT ON;
-- A. Efisiensi rumus rasio total
SELECT 'efisiensi_ratio_total' AS metrik,
  ROUND(100.0*SUM(operating_hours)/NULLIF(SUM(operating_hours+downtime_hours),0),2) AS nilai
FROM fact.FactEquipmentUsage;

-- B. Efisiensi dari staging
SELECT 'efisiensi_staging_ratio' AS metrik,
  ROUND(100.0*SUM(operating_hours)/NULLIF(SUM(operating_hours+downtime_hours),0),2) AS nilai
FROM staging.EquipmentUsage;

-- C. Metal/Ore dari staging (volume dan quantity)
SELECT material_type, SUM(produced_volume) AS vol, SUM(quantity) AS qty, COUNT(*) AS n
FROM staging.Production GROUP BY material_type;

-- D. Metal/Ore dari fakta, per production_id unik
SELECT m.material_type,
  SUM(x.produced_volume) AS vol_unik, SUM(x.material_quantity) AS qty_unik
FROM (SELECT DISTINCT production_id, material_key, produced_volume, material_quantity
      FROM fact.FactProduction) x
JOIN dim.DimMaterial m ON m.material_key=x.material_key
GROUP BY m.material_type;

-- E. Metal/Ore dari fakta, SUM(total_cost) dan jumlah baris
SELECT m.material_type, SUM(f.total_cost) AS total_cost, COUNT(*) AS n
FROM fact.FactProduction f JOIN dim.DimMaterial m ON m.material_key=f.material_key
GROUP BY m.material_type;
GO