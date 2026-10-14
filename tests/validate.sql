SET NOCOUNT ON;
USE PTXYZ_DataWarehouse;
GO
CREATE TABLE #r (kategori varchar(12), pengujian varchar(80), diharapkan varchar(40), hasil varchar(40), status varchar(5));
CREATE TABLE #expected (s sysname, t sysname, col sysname, dt varchar(50), len int, prec int, scale int);
:r /tests/expected_schema.sql
GO

-- 1. SKEMA (nama tabel/kolom/tipe)
INSERT #r SELECT 'SKEMA','kolom hilang / tipe berbeda','0',CAST(COUNT(*) AS varchar(20)),CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END
FROM #expected e LEFT JOIN INFORMATION_SCHEMA.COLUMNS c
    ON c.TABLE_SCHEMA=e.s AND c.TABLE_NAME=e.t AND c.COLUMN_NAME=e.col AND c.DATA_TYPE=e.dt
 AND ISNULL(CAST(c.CHARACTER_MAXIMUM_LENGTH AS int),-1)=ISNULL(e.len,-1)
 AND ISNULL(CAST(c.NUMERIC_PRECISION AS int),-1)=ISNULL(e.prec,-1)
 AND ISNULL(CAST(c.NUMERIC_SCALE AS int),-1)=ISNULL(e.scale,-1)
WHERE c.COLUMN_NAME IS NULL;

INSERT #r SELECT 'SKEMA','kolom tambahan di dim/fact','0',CAST(COUNT(*) AS varchar(20)),CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END
FROM INFORMATION_SCHEMA.COLUMNS c LEFT JOIN #expected e
  ON c.TABLE_SCHEMA=e.s AND c.TABLE_NAME=e.t AND c.COLUMN_NAME=e.col
WHERE c.TABLE_SCHEMA IN ('dim','fact') AND e.col IS NULL;

-- 2. JUMLAH BARIS (README)
INSERT #r SELECT 'BARIS','dim.DimTime','830',CAST(c AS varchar(20)),CASE WHEN c=830 THEN 'PASS' ELSE 'FAIL' END FROM (SELECT COUNT(*) c FROM dim.DimTime) x;
INSERT #r SELECT 'BARIS','dim.DimSite','1747',CAST(c AS varchar(20)),CASE WHEN c=1747 THEN 'PASS' ELSE 'FAIL' END FROM (SELECT COUNT(*) c FROM dim.DimSite) x;
INSERT #r SELECT 'BARIS','dim.DimEquipment','6',CAST(c AS varchar(20)),CASE WHEN c=6 THEN 'PASS' ELSE 'FAIL' END FROM (SELECT COUNT(*) c FROM dim.DimEquipment) x;
INSERT #r SELECT 'BARIS','dim.DimMaterial','5',CAST(c AS varchar(20)),CASE WHEN c=5 THEN 'PASS' ELSE 'FAIL' END FROM (SELECT COUNT(*) c FROM dim.DimMaterial) x;
INSERT #r SELECT 'BARIS','dim.DimEmployee','10',CAST(c AS varchar(20)),CASE WHEN c=10 THEN 'PASS' ELSE 'FAIL' END FROM (SELECT COUNT(*) c FROM dim.DimEmployee) x;
INSERT #r SELECT 'BARIS','dim.DimShift','3',CAST(c AS varchar(20)),CASE WHEN c=3 THEN 'PASS' ELSE 'FAIL' END FROM (SELECT COUNT(*) c FROM dim.DimShift) x;
INSERT #r SELECT 'BARIS','dim.DimProject','50',CAST(c AS varchar(20)),CASE WHEN c=50 THEN 'PASS' ELSE 'FAIL' END FROM (SELECT COUNT(*) c FROM dim.DimProject) x;
INSERT #r SELECT 'BARIS','dim.DimAccount','30',CAST(c AS varchar(20)),CASE WHEN c=30 THEN 'PASS' ELSE 'FAIL' END FROM (SELECT COUNT(*) c FROM dim.DimAccount) x;
INSERT #r SELECT 'BARIS','fact.FactEquipmentUsage','236892',CAST(c AS varchar(20)),CASE WHEN c=236892 THEN 'PASS' ELSE 'FAIL' END FROM (SELECT COUNT(*) c FROM fact.FactEquipmentUsage) x;
INSERT #r SELECT 'BARIS','fact.FactProduction','2261',CAST(c AS varchar(20)),CASE WHEN c=2261 THEN 'PASS' ELSE 'FAIL' END FROM (SELECT COUNT(*) c FROM fact.FactProduction) x;
INSERT #r SELECT 'BARIS','fact.FactFinancialTransaction','115901',CAST(c AS varchar(20)),CASE WHEN c=115901 THEN 'PASS' ELSE 'FAIL' END FROM (SELECT COUNT(*) c FROM fact.FactFinancialTransaction) x;

-- 3. INTEGRITAS REFERENSIAL
INSERT #r SELECT 'FK','jumlah FK di tabel fakta','12',CAST(COUNT(*) AS varchar(20)),CASE WHEN COUNT(*)=12 THEN 'PASS' ELSE 'FAIL' END
FROM sys.foreign_keys WHERE OBJECT_SCHEMA_NAME(parent_object_id)='fact';
INSERT #r SELECT 'FK','FK nonaktif / not trusted','0',CAST(COUNT(*) AS varchar(20)),CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END
FROM sys.foreign_keys WHERE OBJECT_SCHEMA_NAME(parent_object_id)='fact' AND (is_disabled=1 OR is_not_trusted=1);

DECLARE @sql nvarchar(max)=N'', @n int=0;
SELECT @sql += N'SELECT @n = @n + COUNT(*) FROM '+QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id))+N'.'+QUOTENAME(OBJECT_NAME(fk.parent_object_id))
  +N' c LEFT JOIN '+QUOTENAME(OBJECT_SCHEMA_NAME(fk.referenced_object_id))+N'.'+QUOTENAME(OBJECT_NAME(fk.referenced_object_id))
  +N' p ON c.'+QUOTENAME(pc.name)+N' = p.'+QUOTENAME(rc.name)+N' WHERE p.'+QUOTENAME(rc.name)+N' IS NULL; '
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id=fk.object_id
JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id
WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id)='fact';
EXEC sp_executesql @sql, N'@n int OUTPUT', @n=@n OUTPUT;
INSERT #r VALUES ('FK','baris fakta orphan (semua FK)','0',CAST(@n AS varchar(20)),CASE WHEN @n=0 THEN 'PASS' ELSE 'FAIL' END);

-- 4. AGREGAT README (tanggal acuan tetap, setara GETDATE() sekitar 29-31 Mei 2025)
DECLARE @metal decimal(18,2), @ore decimal(18,2), @eff float;
SELECT @metal = SUM(CASE WHEN dm.material_type='Metal' THEN fp.produced_volume END),
       @ore   = SUM(CASE WHEN dm.material_type='Ore'   THEN fp.produced_volume END)
FROM fact.FactProduction fp JOIN dim.DimMaterial dm ON fp.material_key=dm.material_key
JOIN dim.DimTime dt ON fp.time_key=dt.time_key WHERE dt.date >= '2025-05-01';
INSERT #r VALUES ('AGREGAT','produksi Metal (date >= 2025-05-01)','434721',CAST(@metal AS varchar(40)),CASE WHEN @metal=434721 THEN 'PASS' ELSE 'FAIL' END);
INSERT #r VALUES ('AGREGAT','produksi Ore (date >= 2025-05-01)','112687',CAST(@ore AS varchar(40)),CASE WHEN @ore=112687 THEN 'PASS' ELSE 'FAIL' END);
SELECT @eff = AVG(CAST(f.operating_hours AS float)/NULLIF(f.operating_hours+f.downtime_hours,0)*100)
FROM fact.FactEquipmentUsage f JOIN dim.DimTime dt ON f.time_key=dt.time_key WHERE dt.date >= '2025-05-22';
INSERT #r VALUES ('AGREGAT','efisiensi % (date >= 2025-05-22)','95.66',CAST(ROUND(@eff,2) AS varchar(40)),CASE WHEN ABS(@eff-95.66)<0.005 THEN 'PASS' ELSE 'FAIL' END);

-- 5. KUALITAS DATA (informasi, tidak menggagalkan tes)
INSERT #r SELECT 'DQ','DimSite: baris vs site_name unik','info',CAST(COUNT(*) AS varchar(10))+' vs '+CAST(COUNT(DISTINCT site_name) AS varchar(10)),'INFO' FROM dim.DimSite;
INSERT #r SELECT 'DQ','FactEquipmentUsage: baris vs ID sumber unik','info',CAST(COUNT(*) AS varchar(10))+' vs '+CAST(COUNT(DISTINCT equipment_usage_id) AS varchar(10)),'INFO' FROM fact.FactEquipmentUsage;
INSERT #r SELECT 'DQ','nilai negatif (jam/volume/biaya)','0',CAST(
  (SELECT COUNT(*) FROM fact.FactEquipmentUsage WHERE operating_hours<0 OR downtime_hours<0 OR fuel_consumption<0 OR maintenance_cost<0)
 +(SELECT COUNT(*) FROM fact.FactProduction WHERE produced_volume<0 OR unit_cost<0)
 +(SELECT COUNT(*) FROM fact.FactFinancialTransaction WHERE budgeted_cost<0 OR actual_cost<0) AS varchar(20)),
 CASE WHEN (SELECT COUNT(*) FROM fact.FactEquipmentUsage WHERE operating_hours<0 OR downtime_hours<0 OR fuel_consumption<0 OR maintenance_cost<0)
      +(SELECT COUNT(*) FROM fact.FactProduction WHERE produced_volume<0 OR unit_cost<0)
      +(SELECT COUNT(*) FROM fact.FactFinancialTransaction WHERE budgeted_cost<0 OR actual_cost<0)=0 THEN 'PASS' ELSE 'WARN' END;

-- RINGKASAN
SELECT kategori, pengujian, diharapkan, hasil, status FROM #r;
SELECT SUM(CASE WHEN status='PASS' THEN 1 ELSE 0 END) AS lulus,
       SUM(CASE WHEN status='FAIL' THEN 1 ELSE 0 END) AS gagal,
       SUM(CASE WHEN status IN ('INFO','WARN') THEN 1 ELSE 0 END) AS catatan FROM #r;
IF EXISTS (SELECT 1 FROM #r WHERE status='FAIL') THROW 50001, 'VALIDASI GAGAL: ada pengujian FAIL', 1;
GO