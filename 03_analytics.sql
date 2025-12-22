


-- =============================================
-- 1. VIEW: Historical Stock Valuation
-- Description: Aggregates the quantity and value of goods purchased to date.
-- Usage: Inventory audits and asset valuation.
-- =============================================
create or alter view v_stock_valuation as
select 
    w.LocationName,
    p.ProductName,
    p.SKU,
    sum(l.QuantityChange) as HistoricalQuantity,
    sum(l.QuantityChange) * p.UnitCost as HistoricalValue
from InventoryLedger l
join Products p on l.ProductID = p.ProductID
join Warehouses w on l.WarehouseID = w.WarehouseID
where l.TransactionDate <= getdate()
group by w.LocationName, p.ProductName, p.SKU, p.UnitCost
having sum(l.QuantityChange) > 0;
go


-- 2. VIEW: Customer Segmentation
-- Description: Classifies customers based on Recency, Frequency, and Monetary value.
-- Usage: Marketing, campaign targeting, VIP identification.
create or alter view v_customer_rfm_segmentation as
with customer_stats as (
    select 
        c.CustomerID,
        c.FirstName,
        c.LastName,
        datediff(day, max(o.OrderDate), current_timestamp) as RecencyDays,
        count(o.OrderID) as FrequencyOrders,
        sum(o.TotalAmount) as MonetaryTotal
    from Customers c
    join Orders o on c.CustomerID = o.CustomerID
    where o.Status != 'CANCELLED'
    group by c.CustomerID, c.FirstName, c.LastName
),
rfm_score as (
    select 
        *,
        ntile(4) over (order by RecencyDays desc) as R_Score,
        ntile(4) over (order by FrequencyOrders asc) as F_Score,
        ntile(4) over (order by MonetaryTotal asc) as M_Score
    from customer_stats
)
select 
    FirstName, 
    LastName,
    RecencyDays,
    FrequencyOrders,
    MonetaryTotal,
    case 
        when R_Score = 4 and F_Score = 4 and M_Score = 4 then 'CHAMPION'
        when R_Score = 1 then 'LOST'
        when F_Score = 4 then 'LOYAL'
        else 'STANDARD'
    end as CustomerSegment
from rfm_score;
go

-- 3. VIEW: Supplier Quality Analysis
-- Description: Analysis of return rates broken down by supplier.
-- Usage: Contract negotiations, supply chain quality control.
create or alter view v_supplier_performance as
select 
    s.SupplierName,
    count(distinct p.ProductID) as ProductsSupplied,
    abs(sum(case when l.TransactionType = 'SALE' then l.QuantityChange else 0 end)) as TotalUnitsSold,
    sum(case when l.TransactionType = 'RETURN' then l.QuantityChange else 0 end) as TotalUnitsReturned,
    cast(
        sum(case when l.TransactionType = 'RETURN' then l.QuantityChange else 0 end) * 1.0 
        / 
        nullif(abs(sum(case when l.TransactionType = 'SALE' then l.QuantityChange else 0 end)), 0)
    as decimal(5,2)) * 100 as ReturnRatePercent
from Suppliers s
join Products p on s.SupplierID = p.SupplierID
join InventoryLedger l on p.ProductID = l.ProductID
group by s.SupplierName
having abs(sum(case when l.TransactionType = 'SALE' then l.QuantityChange else 0 end)) > 50;
go

-- 4. VIEW: Returns Log
-- Description: Detailed view of orders marked as returned.
-- Usage: Customer service, return cause analysis.
create or alter view v_returned_orders_log as
select 
    o.OrderID,
    o.OrderDate,
    o.Status as OrderStatus, -- Changed from Status_w_Orders to OrderStatus (English consistency)
    l.TransactionType,          
    l.QuantityChange,            
    l.TransactionDate
from Orders o
join InventoryLedger l on o.OrderID = l.ReferenceID
where o.Status = 'RETURNED';
go


-- 5. VIEW: Market Basket Affinity
-- Description: Identifies pairs of products purchased within the same order.
-- Usage: Product recommendations, cross-selling.
create or alter view v_market_basket_affinity as
with product_pairs as (
    select 
        oi1.ProductID as ProductA,
        p1.ProductName as NameA,
        oi2.ProductID as ProductB,
        p2.ProductName as NameB
    from OrderItems oi1
    join OrderItems oi2 on oi1.OrderID = oi2.OrderID 
        and oi1.ProductID < oi2.ProductID 
    join Products p1 on oi1.ProductID = p1.ProductID
    join Products p2 on oi2.ProductID = p2.ProductID
)
select top 100 percent
    NameA,
    NameB,
    count(*) as Frequency
from product_pairs
group by NameA, NameB, ProductA, ProductB;
go

-- 6. VIEW: Product Profitability
-- Description: Calculates margin and profit per product and category.
-- Usage: Assortment optimization, pricing decisions.
create or alter view v_product_profitability as
select 
    p.Category,
    p.ProductName,
    abs(sum(case when l.TransactionType = 'SALE' then l.QuantityChange else 0 end)) as UnitsSold,
    sum(abs(case when l.TransactionType = 'SALE' then l.QuantityChange else 0 end) * p.UnitPrice) as TotalRevenue,
    sum(abs(case when l.TransactionType = 'SALE' then l.QuantityChange else 0 end) * p.UnitCost) as TotalCost,
    sum(abs(case when l.TransactionType = 'SALE' then l.QuantityChange else 0 end) * (p.UnitPrice - p.UnitCost)) as TotalProfit,
    cast(avg((p.UnitPrice - p.UnitCost) / p.UnitPrice) * 100 as decimal(5,2)) as MarginPercent
from InventoryLedger l
join Products p on l.ProductID = p.ProductID
where l.TransactionType = 'SALE'
group by p.Category, p.ProductName, p.UnitPrice, p.UnitCost
having abs(sum(l.QuantityChange)) > 10;
go

-- 7. VIEW: Daily Sales Trends
-- Description: Daily sales analysis with moving average.
-- Usage: Anomaly detection and short-term trend analysis.
create or alter view v_daily_sales_trends as
with daily_sales as (
    select 
        cast(TransactionDate as date) as SaleDate,
        abs(sum(QuantityChange)) as DailyQty
    from InventoryLedger
    where TransactionType = 'SALE'
    group by cast(TransactionDate as date)
)
select 
    SaleDate,
    DailyQty,
    avg(DailyQty) over (
        order by SaleDate 
        rows between 6 preceding and current row
    ) as MovingAvg_7Days,
    case 
        when DailyQty > avg(DailyQty) over (order by SaleDate rows between 6 preceding and current row) 
        then 'ABOVE TREND' 
        else 'BELOW TREND' 
    end as Status
from daily_sales;
go

-- 8. VIEW: Main KPI Dashboard (Daily Business KPIs)
-- Description: Comprehensive daily view covering revenue, margins, and returns.
-- Usage: Executive reporting.
create or alter view v_daily_business_kpis as
with daily_stats as (
    select 
        cast(TransactionDate as date) as ReportDate,
        sum(case when TransactionType = 'SALE' then abs(QuantityChange) * p.UnitPrice else 0 end) as Revenue,
        sum(case when TransactionType = 'SALE' then abs(QuantityChange) * p.UnitCost else 0 end) as COGS,
        sum(case when TransactionType = 'RETURN' then QuantityChange else 0 end) as ReturnedItems,
        sum(case when TransactionType = 'SALE' then abs(QuantityChange) else 0 end) as SoldItems
    from InventoryLedger l
    join Products p on l.ProductID = p.ProductID
    group by cast(TransactionDate as date)
)
select 
    ReportDate,
    cast(Revenue as decimal(10,2)) as Revenue,
    cast(Revenue - COGS as decimal(10,2)) as GrossProfit,
    cast(case 
        when Revenue = 0 then 0 
        else (Revenue - COGS) / Revenue * 100 
    end as decimal(5,2)) as MarginPercent,
    cast(avg(Revenue) over (order by ReportDate rows between 6 preceding and current row) as decimal(10,2)) as MovingAvgRev7D,
    case 
        when Revenue > avg(Revenue) over (order by ReportDate rows between 6 preceding and current row) 
        then 'ABOVE TREND' else 'BELOW TREND' 
    end as TrendStatus,
    ReturnedItems,
    cast(case 
        when SoldItems = 0 then 0 
        else ReturnedItems * 1.0 / SoldItems * 100 
    end as decimal(5,2)) as ReturnRatePercent
from daily_stats;
go

-- 9. VIEW: Product ABC Classification 
-- Description: Segmentation of products into A, B, C groups based on revenue generated.
-- Usage: Inventory management, supply prioritization.
create or alter view v_product_abc_classification as
with product_revenue as (
    select 
        p.ProductName,
        sum(l.QuantityChange * p.UnitPrice * -1) as Revenue 
    from InventoryLedger l
    join Products p on l.ProductID = p.ProductID
    where l.TransactionType = 'SALE'
    group by p.ProductName
),
running_totals as (
    select 
        ProductName,
        Revenue,
        sum(Revenue) over () as TotalGlobalRevenue,
        sum(Revenue) over (order by Revenue desc) as RunningRevenue
    from product_revenue
)
select 
    ProductName,
    Revenue,
    cast(Revenue * 100.0 / TotalGlobalRevenue as decimal(5,2)) as SharePercent,
    cast(RunningRevenue * 100.0 / TotalGlobalRevenue as decimal(5,2)) as CumulativeShare,
    case 
        when RunningRevenue * 100.0 / TotalGlobalRevenue <= 80 then 'A' 
        when RunningRevenue * 100.0 / TotalGlobalRevenue <= 95 then 'B' 
        else 'C' 
    end as ABC_Class
from running_totals;
go

-- 10. VIEW: Monthly Growth (MoM)
-- Description: Analysis of sales dynamics month-over-month.
-- Usage: Long-term trend tracking.
create or alter view v_monthly_sales_growth as
with monthly_sales as (
    select 
        year(TransactionDate) as SalesYear,
        month(TransactionDate) as SalesMonth,
        abs(sum(QuantityChange * p.UnitPrice)) as Revenue 
    from InventoryLedger l
    join Products p on l.ProductID = p.ProductID
    where l.TransactionType = 'SALE'
    group by year(TransactionDate), month(TransactionDate)
),
growth_calc as (
    select 
        SalesYear,
        SalesMonth,
        Revenue,
        lag(Revenue) over (order by SalesYear, SalesMonth) as PrevMonthRevenue
    from monthly_sales
)
select 
    cast(SalesYear as varchar) + '-' + right('00' + cast(SalesMonth as varchar), 2) as Period,
    Revenue,
    PrevMonthRevenue,
    cast(
        (Revenue - PrevMonthRevenue) * 100.0 / nullif(PrevMonthRevenue, 0) 
    as decimal(5,2)) as MoM_Growth_Percent,
    case 
        when Revenue > PrevMonthRevenue then 'GROWTH'
        when Revenue < PrevMonthRevenue then 'DECLINE'
        else 'STABLE'
    end as Trend
from growth_calc;
go

-- 11. VIEW: Dead Stock Alerts
-- Description: Products lingering in the warehouse (no sales for >90 days or ever).
-- Usage: Clearance sales, warehouse cleaning, cash release.
create or alter view v_dead_stock_alerts as
select 
    p.ProductName,
    p.Category,
    w.LocationName,
    sum(l.QuantityChange) as CurrentStockQuantity,
    sum(l.QuantityChange * p.UnitCost) as FrozenCashValue, 
    datediff(day, max(l.TransactionDate), getdate()) as DaysSinceLastMovement
from InventoryLedger l
join Products p on l.ProductID = p.ProductID
join Warehouses w on l.WarehouseID = w.WarehouseID
group by p.ProductName, p.Category, w.LocationName, p.UnitCost
having 
    sum(l.QuantityChange) > 0 
    and (
        max(case when l.TransactionType = 'SALE' then l.TransactionDate end) < dateadd(day, -90, getdate())
        or
        max(case when l.TransactionType = 'SALE' then l.TransactionDate end) is null
     );
go


-- 12. PROCEDURE: Sales Report by Category within Date Range
-- Description: Allows business users to generate on-demand reports.
-- Usage: BI integration, ad-hoc reporting.

create or alter procedure usp_GetCategoryPerformance
    @CategoryName varchar(50),
    @StartDate date,
    @EndDate date
as
begin
    set nocount on;

    select 
        p.ProductName,
        sum(abs(l.QuantityChange)) as TotalUnitsSold,
        sum(abs(l.QuantityChange) * p.UnitPrice) as TotalRevenue
    from InventoryLedger l
    join Products p on l.ProductID = p.ProductID
    where 
        p.Category = @CategoryName
        and l.TransactionType = 'SALE'
        and l.TransactionDate between @StartDate and @EndDate
    group by p.ProductName
    order by TotalRevenue desc;
end;
go

select * from v_customer_rfm_segmentation order by MonetaryTotal desc;
select * from v_product_abc_classification where ABC_Class = 'A';
select top 10 * from v_market_basket_affinity order by Frequency desc;
select * from v_dead_stock_alerts order by FrozenCashValue desc;

exec usp_GetCategoryPerformance 'Electronics', '2023-01-01', '2023-12-31';