SET NOCOUNT ON;
SELECT m.material_name, m.material_type,
  SUM(f.produced_volume) AS vol, SUM(f.material_quantity) AS qty, COUNT(*) AS n
FROM fact.FactProduction f JOIN dim.DimMaterial m ON m.material_key=f.material_key
GROUP BY m.material_name, m.material_type ORDER BY 2,1;

SELECT COUNT(*) AS n_baris_site, COUNT(DISTINCT site_name) AS site_nama_unik,
  COUNT(DISTINCT site_id) AS site_id_unik FROM dim.DimSite;
GO