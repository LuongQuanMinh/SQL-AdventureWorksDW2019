x`USE AdventureWorksDW2019;

/*
Q1:
From FactInternetSales, DimProduct, query the list of products that satisfy:
- Orders shipped in Q1 2013
- Color is not Silver
- ProductSubCategoryKey is no 20
*/

SELECT
    FIS.ProductKey
    , EnglishProductName as ProductName
    , Color as ProductColor
    , count(distinct FIS.SalesOrderNumber) AS No_Order
    , count(distinct CustomerKey) as No_Customer
FROM
    FactInternetSales AS FIS
    INNER JOIN DimProduct ON FIS.ProductKey = DimProduct.ProductKey
WHERE
    FIS.ShipDateKey BETWEEN 20130101 AND 20130331
    AND DimProduct.Color NOT like ('%Silver%')
    AND DimProduct.ProductSubCategoryKey != 20
group by
    FIS.ProductKey
    , EnglishProductName
    , Color
order by 1    
;


/*
Q2:
From FactInternetSales, FactResellerSales, DimProduct, calculate:
    - InternetTotalSales
    - ResellerTotalSales
    - NoOrder
    - NoCustomer
*/

with InternetSalesSummary as (
    SELECT
        YEAR(ShipDate) as YearReport
        , FORMAT (ShipDate, 'yyyy-MM') as MonthReport
        -- , MONTH(ShipDate) as MonthReport
        , EnglishProductSubcategoryName as ProductSubCategoryName
        , sum(SalesAmount) as InternetTotalSales
        , count(distinct SalesOrderNumber) as NoOrder
        , count(distinct CustomerKey) as NoCustomer
        , 'Internet' as SalesType
    from FactInternetSales AS FIS
    left JOIN DimProduct ON FIS.ProductKey = DimProduct.ProductKey
    left join DimProductSubCategory on DimProduct.ProductSubCategoryKey = DimProductSubCategory.ProductSubCategoryKey
    GROUP BY
        YEAR(ShipDate)
        -- , MONTH(ShipDate)
        , FORMAT (ShipDate, 'yyyy-MM')
        , EnglishProductSubcategoryName
)

, ResellerSalesSummary as (
    SELECT
        YEAR(ShipDate) as YearReport
        , FORMAT (ShipDate, 'yyyy-MM') as MonthReport
        -- , MONTH(ShipDate) as MonthReport
        , EnglishProductSubcategoryName as ProductSubCategoryName
        , sum(SalesAmount) as ResellerTotalSales
        , count(distinct SalesOrderNumber) as NoOrder
        , count(distinct ResellerKey) as NoCustomer
        , 'Reseller' as SalesType
    from FactResellerSales AS FRS
    left JOIN DimProduct ON FRS.ProductKey = DimProduct.ProductKey
    left join DimProductSubCategory on DimProduct.ProductSubCategoryKey = DimProductSubCategory.ProductSubCategoryKey
    GROUP BY
        YEAR(ShipDate)
        , FORMAT (ShipDate, 'yyyy-MM')
        -- , MONTH(ShipDate)
        , EnglishProductSubcategoryName
)

, YearMonthName AS (
    SELECT 
        YearReport,
        MonthReport,
        ProductSubcategoryName
    FROM InternetSalesSummary
    
    UNION

    SELECT 
        YearReport,
        MonthReport,
        ProductSubcategoryName
    FROM ResellerSalesSummary
    )

select
    YearMonthName.YearReport
    , YearMonthName.MonthReport
    , YearMonthName.ProductSubCategoryName
    , InternetTotalSales
    , ResellerTotalSales
    , isnull(ISS.NoOrder,0) + isnull(RSS.NoOrder,0) as NoOrder
    , isnull(ISS.NoCustomer,0) + isnull(RSS.NoCustomer,0) as NoCustomer
from 
    YearMonthName
    left join InternetSalesSummary as ISS
        on YearMonthName.YearReport = ISS.YearReport 
        and YearMonthName.MonthReport = ISS.MonthReport 
        and YearMonthName.ProductSubCategoryName = ISS.ProductSubCategoryName
    left join ResellerSalesSummary as RSS 
        on YearMonthName.YearReport = RSS.YearReport
        and YearMonthName.MonthReport = RSS.MonthReport
        and YearMonthName.ProductSubCategoryName = RSS.ProductSubCategoryName
order by 1,2,3
;


/*
Q3:
From FactInternetSales, FactResellerSales calculate:
    - IsWorkingDay
    - InternetSalesTotal
    - InternetNoOrder
    - ResellerSalesTotal
    - ResellerNoOrder
*/

with InternetSales as 
(
    select OrderDate
    ,   sum(SalesAmount) as InternetAmount
    ,   count(distinct SalesOrderNumber) as InternetNumber
    from FactInternetSales
    group by OrderDate
),
ResellerSales as 
(
    select OrderDate
    ,   sum(SalesAmount) as ResellerAmount
    ,   count(distinct SalesOrderNumber) as ResellerNumber
    from FactResellerSales
    group by OrderDate
),
DateOfOrder as 
(
    select OrderDate as OD from FactInternetSales
    union 
    select OrderDate as OD from FactResellerSales
)
select 
    format(OD,'dd-MMM-yyyy') as OrderDate
,   case 
        when datepart(dw,OD) = 1 then 0
        when datepart(dw,OD) = 7 then 0
        when month(OD) = 12 and day(OD) >= 22 then 0
        when month(OD) = 1 and day(OD) <= 5 then 0
        else 1
    end as IsWorkingDay
,   isnull(InternetAmount,0) as InternetSalesTotal
,   isnull(InternetNumber,0) as InternetNoOrder
,   isnull(ResellerAmount,0) as ResellerSalesTotal
,   isnull(ResellerNumber,0) as ResellerNoOrder
from DateOfOrder 
full join InternetSales ON DateOfOrder.OD = InternetSales.OrderDate
full join ResellerSales ON DateOfOrder.OD = ResellerSales.OrderDate
ORDER BY OD;

/*
Q4:
The management of the company wants to know the following information of each month:
    - No of orders
    - No of shipped orders
    - DiscountPercentage (TotalDiscountAmount / TotalSalesAmount)
    - ProfitMargin (TotalSalesAmount - TotalCostAmount)/TotalSalesAmount
    - SalesAmountRankingByYear
*/

with 
DimMonth as (
    select DISTINCT
        YEAR(DimDate.FullDateAlternateKey) as Year
        , FORMAT (DimDate.FullDateAlternateKey, 'yyyy-MM') as Month
    from DimDate
    WHERE DateKey BETWEEN 20101201 AND 20140228
)

, InternetSales as (
    select 
        YEAR(OrderDate) as Year
        , FORMAT (OrderDate, 'yyyy-MM') as Month
        , count(distinct Sales.SalesOrderNumber) as #NewOrder
        , sum(Sales.DiscountAmount)/sum(Sales.SalesAmount) as DiscountPercentage
        , (sum(Sales.SalesAmount) - sum(Sales.TotalProductCost))/sum(Sales.SalesAmount) as ProfitMargin
        , rank() over (partition by
                            YEAR(OrderDate)
                         order by sum(Sales.SalesAmount) desc) as SalesAmountRankingByYear
        , sum(Sales.SalesAmount) as SalesAmount
              
    from FactInternetSales Sales    
    GROUP BY
        YEAR(OrderDate)
        , FORMAT (OrderDate, 'yyyy-MM')
)

, InternetShipped as (
    select 
        YEAR(ShipDate) as Year
        , FORMAT (ShipDate, 'yyyy-MM') as Month
        , count(distinct Shipped.SalesOrderNumber) as #ShippedOrder
    from  FactInternetSales Shipped
    GROUP BY
        YEAR(ShipDate)
        , FORMAT (ShipDate, 'yyyy-MM')


, InternetCombined as (
    select 
        DimMonth.Year
        , DimMonth.Month
        , 'Internet' as SalesChannel
        , InternetSales.#NewOrder
        , InternetShipped.#ShippedOrder
        , InternetSales.DiscountPercentage
        , InternetSales.ProfitMargin
        , InternetSales.SalesAmountRankingByYear
        -- , InternetSales.SalesAmount
    from DimMonth
    left join InternetSales
        on DimMonth.Year = InternetSales.Year and DimMonth.Month = InternetSales.Month
    left join InternetShipped 
        on DimMonth.Year = InternetShipped.Year and DimMonth.Month = InternetShipped.Month
)

, ResellerSales as (
    select 
        YEAR(OrderDate) as Year
        , FORMAT (OrderDate, 'yyyy-MM') as Month
        , count(distinct Sales.SalesOrderNumber) as #NewOrder
        , sum(Sales.DiscountAmount)/sum(Sales.SalesAmount) as DiscountPercentage
        , (sum(Sales.SalesAmount) - sum(Sales.TotalProductCost))/sum(Sales.SalesAmount) as ProfitMargin
        , rank() over (partition by
                            YEAR(OrderDate)
                         order by sum(Sales.SalesAmount) desc) as SalesAmountRankingByYear
        , sum(Sales.SalesAmount) as SalesAmount
    from FactResellerSales Sales
    GROUP BY
        YEAR(OrderDate)
        , FORMAT (OrderDate, 'yyyy-MM')
)

, ResellerShipped as (
    select 
        YEAR(ShipDate) as Year
        , FORMAT (ShipDate, 'yyyy-MM') as Month
        , count(distinct Shipped.SalesOrderNumber) as #ShippedOrder
    from FactResellerSales Shipped
    GROUP BY
        YEAR(ShipDate)
        , FORMAT (ShipDate, 'yyyy-MM')
)

, ResellerCombined as (
    select 
        DimMonth.Year
        , DimMonth.Month
        , 'Reseller' as SalesChannel
        , ResellerSales.#NewOrder
        , ResellerShipped.#ShippedOrder
        , ResellerSales.DiscountPercentage
        , ResellerSales.ProfitMargin
        , ResellerSales.SalesAmountRankingByYear
        -- , ResellerSales.SalesAmount
    from DimMonth
    left join ResellerSales
        on DimMonth.Year = ResellerSales.Year and DimMonth.Month = ResellerSales.Month
    left join ResellerShipped
        on DimMonth.Year = ResellerShipped.Year and DimMonth.Month = ResellerShipped.Month
)

SELECT * from (
    SELECT
        *
    FROM
        InternetCombined
    UNION ALL
    SELECT
        *
    FROM
        ResellerCombined
    ) as SalesCombined
order by 1,2,3