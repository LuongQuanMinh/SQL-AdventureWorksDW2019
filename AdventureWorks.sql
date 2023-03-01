-- CAu 1 Từ bảng DimProduct, DimSalesTerritory và FactInternetSales, hãy truy vấn ra các thông tin sau của các đơn hàng được đặt trong 
--năm 2013 và 2014:
SELECT SalesOrderNumber
, SalesOrderLineNumber
, InternetSales.ProductKey
, EnglishProductName
, SalesTerritoryCountry
, SalesAmount
, OrderQuantity
FROM FactInternetSales AS InternetSales
LEFT JOIN DimProduct AS Product on Product.ProductKey = InternetSales.ProductKey
LEFT JOIN DimSalesTerritory AS Territory on Territory.SalesTerritoryKey = InternetSales.SalesTerritoryKey
WHERE YEAR(OrderDate) in (2013, 2014)

--Câu 2: (2đ)
--Từ bảng DimProduct, DimSalesTerritory và FactInternetSales, tính tổng doanh thu (đặt tên là InternetTotalSales) và số đơn hàng 
--(đặt tên là NumberofOrders) của từng sản phẩm theo mỗi quốc gia từ bảng DimSalesTerritory.

SELECT SalesTerritoryCountry
, InternetSales.ProductKey
, SUM(SalesAmount) as InternetTotalSales
, COUNT(InternetSales.ProductKey) as NumberOfOrders
FROM FactInternetSales AS InternetSales
LEFT JOIN DimProduct AS Product on Product.ProductKey = InternetSales.ProductKey
LEFT JOIN DimSalesTerritory AS Territory on Territory.SalesTerritoryKey = InternetSales.SalesTerritoryKey
GROUP BY SalesTerritoryCountry
, InternetSales.ProductKey
ORDER BY InternetSales.ProductKey, SalesTerritoryCountry

--Câu 3: (2đ)
--Từ bảng DimProduct, DimSalesTerritory và FactInternetSales, hãy tính toán % tỷ trọng doanh thu của từng sản phẩm (đặt tên là 
--PercentofTotaInCountry) trong Tổng doanh thu của mỗi quốc gia. Kết quả trả về gồm có các thông tin sau: 

WITH TotalCountry AS
(
SELECT  SalesTerritoryCountry
, SUM(SalesAmount) as TotalByCoutry
FROM FactInternetSales AS InternetSales
LEFT JOIN DimSalesTerritory AS Territory on Territory.SalesTerritoryKey = InternetSales.SalesTerritoryKey
GROUP BY SalesTerritoryCountry
)

SELECT  Territory.SalesTerritoryCountry
, InternetSales.ProductKey
, SUM(SalesAmount) as InternetTotalSales
, COUNT(InternetSales.ProductKey) as NumberOfOrders
, Format(SUM(SalesAmount)/TotalByCoutry ,'P') as PercentofTotaInCountry 
FROM FactInternetSales AS InternetSales
LEFT JOIN DimProduct AS Product on Product.ProductKey = InternetSales.ProductKey
LEFT JOIN DimSalesTerritory AS Territory on Territory.SalesTerritoryKey = InternetSales.SalesTerritoryKey
LEFT JOIN TotalCountry ON TotalCountry. SalesTerritoryCountry = Territory.SalesTerritoryCountry
GROUP BY  Territory.SalesTerritoryCountry
, InternetSales.ProductKey
, TotalByCoutry
ORDER BY   Territory.SalesTerritoryCountry

--Câu 4: (2đ)
--Từ bảng FactInternetSales, và DimCustomer, hãy truy vấn ra danh sách top 3 khách hàng có tổng doanh thu tháng (đặt tên là 
--CustomerMonthAmount) cao nhất trong hệ thống theo mỗi tháng. 

WITH ResultTable AS
(
SELECT YEAR(OrderDate) as OrderYear
, MONTH(OrderDate) AS OrderMonth
, InternetSales.CustomerKey As CustomerKey
, CONCAT_WS(' ',FirstName, MiddleName, LastName) as CustomerFullName
, SUM(SalesAmount) as CustomerMonthAccount
, ROW_NUMBER () OVER (Partition By YEAR(OrderDate),MONTH(OrderDate) ORDER BY SUM(SalesAmount)) as CustomerRank
FROM FactInternetSales AS InternetSales
LEFT JOIN DimCustomer AS Customer on Customer.CustomerKey = InternetSales.CustomerKey
GROUP BY YEAR(OrderDate),  MONTH(OrderDate),CONCAT_WS(' ',FirstName, MiddleName, LastName),InternetSales.CustomerKey
)
SELECT OrderYear
, OrderMonth
, CustomerKey
,  CustomerFullName
,  CustomerMonthAccount
FROM ResultTable
WHERE CustomerRank <=3

--Câu 5: (1đ)
--Từ bảng FactInternetSales, tính toán tổng doanh thu theo từng tháng (đặt tên là InternetMonthAmount).
SELECT YEAR(OrderDate) as OrderYear
, MONTH(OrderDate) AS OrderMonth
, SUM(SalesAmount) as InternetMonthAmount
FROM FactInternetSales
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
Order By  YEAR(OrderDate), MONTH(OrderDate)

--Câu 6: (1đ)
--Từ bảng FactInternetSales hãy tính toán % tăng trưởng doanh thu (đặt tên là PercentSalesGrowth) so với cùng kỳ năm trước (ví dụ: 
--Tháng 11 năm 2012 thì so sánh với tháng 11 năm 2011).
WITH SalesCal AS
(
SELECT YEAR(OrderDate) as OrderYear
, MONTH(OrderDate) AS OrderMonth
, SUM(SalesAmount) as InternetMonthAmount
FROM FactInternetSales
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT *
, LAG(InternetMonthAmount,12,0) OVER (ORDER BY  OrderYear,OrderMonth) as InternetMonthAmount_LastYear
, CASE
WHEN LAG(InternetMonthAmount,12,0) OVER (ORDER BY  OrderYear,OrderMonth) =0 then 'Not Enough Data'
ELSE FORMAT((InternetMonthAmount-LAG(InternetMonthAmount,12,0) OVER (ORDER BY  OrderYear,OrderMonth))/LAG(InternetMonthAmount,12,0) OVER (ORDER BY  OrderYear,OrderMonth),'P') 
 END as PercentSalesGrowth
FROM SalesCal
