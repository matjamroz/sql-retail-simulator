-- MAIN PROCEDURE
-- Description: Generates master data and simulates sales/returns history.
create or alter procedure SimulateRetailActivity_Timeline
as
begin
    set nocount on;
    -- 1. CLEANUP SECTION
    -- Clearing existing data to start with a fresh state.
    -- Order matters due to Foreign Key constraints.
    delete from InventoryLedger;
    delete from OrderItems;
    delete from Orders;
    delete from Products;
    delete from Customers;
    delete from Warehouses;
    delete from Brands;
    delete from Suppliers;

    dbcc checkident ('InventoryLedger', reseed, 0);
    dbcc checkident ('OrderItems', reseed, 0);
    dbcc checkident ('Orders', reseed, 0);
    dbcc checkident ('Products', reseed, 0);
    dbcc checkident ('Customers', reseed, 0);

    -- 2. STATIC DATA POPULATION
    -- Inserting foundational data: Suppliers, Brands, Warehouses.
    insert into Suppliers (SupplierName, Country, LeadTimeDays) values
    ('MegaCorp China', 'China', 45), ('EuroLogistics DE', 'Germany', 7), ('Local PL Supply', 'Poland', 2);
    
    insert into Brands (BrandName, TargetAudience) values
    ('Gucci-Fake', 'Budget'), ('SmartTech', 'Mainstream'), ('LuxAudio', 'Premium'), ('EcoWear', 'Mainstream');
    
    insert into Warehouses (LocationName, City, Type) values
    ('Central Hub', 'Warsaw', 'Hub'), ('West Store', 'Poznan', 'LocalStore'), ('South Store', 'Krakow', 'LocalStore');
    
    -- 3. CUSTOMER GENERATION
    -- Generating 2000 synthetic customers using a loop.
    declare @i int = 1;
    begin transaction; 
    while @i <= 2000
    begin
        insert into Customers (FirstName, LastName, Segment, JoinDate)
        values (
            'Jan' + cast(@i as varchar), 
            'Kowalski' + cast(@i as varchar), 
            case when @i % 10 = 0 then 'VIP' else 'Standard' end, 
            dateadd(day, -(@i % 700), getdate())
        );
        set @i = @i + 1;
    end
    commit transaction;

    -- 4. PRODUCT CATALOG GENERATION
    -- Creating 500 products with randomized attributes.
    -- The first 100 are flagged as 'BESTSELLER'.
    set @i = 1;
    begin transaction;
    while @i <= 500
    begin
        declare @IsHit bit = case when @i <= 100 then 1 else 0 end;
        -- Base price randomization between 10.00 and 510.00
        declare @BasePrice decimal(10,2) = 10.0 + (abs(checksum(newid())) % 500);
        
        insert into Products (SKU, ProductName, BrandID, SupplierID, Category, UnitCost, UnitPrice, WeightKG, IsActive)
        values (
            'SKU-' + right('0000' + cast(@i as varchar), 4),
            case when @IsHit=1 then 'BESTSELLER ' else 'Standard ' end + 'Item ' + cast(@i as varchar),
            1 + (abs(checksum(newid())) % 4), -- Random BrandID (1-4)
            1 + (abs(checksum(newid())) % 3), -- Random SupplierID (1-3)
            case when @i % 3 = 0 then 'Electronics' when @i % 3 = 1 then 'Fashion' else 'Home' end,
            @BasePrice, 
            @BasePrice * (case when @IsHit=1 then 1.8 else 1.3 end), -- Higher margin for bestsellers
            1.0, 1
        );
        set @i = @i + 1;
    end

    -- 5. INITIAL INVENTORY STOCK
    -- Adding initial stock entries to the ledger for all created products.
    insert into InventoryLedger (WarehouseID, ProductID, QuantityChange, TransactionType, TransactionDate)
    select 1, ProductID, case when ProductName like 'BESTSELLER%' then 500 else 20 end, 'PURCHASE', dateadd(year, -2, getdate())
    from Products;
    commit transaction;

    -- 6. SALES HISTORY SIMULATION
    -- Iterating through every day from 2 years ago until today.
    -- Volume fluctuates based on month and weekends.
    declare @CurrentDate date = dateadd(year, -2, getdate());
    declare @EndDate date = getdate();
    
    while @CurrentDate <= @EndDate
    begin
        declare @BaseOrders int = 5 + (datediff(month, dateadd(year, -2, getdate()), @CurrentDate) / 2);
        
        if month(@CurrentDate) = 12 set @BaseOrders = @BaseOrders * 2; -- Christmas spike
        if datepart(weekday, @CurrentDate) in (7, 1) set @BaseOrders = @BaseOrders * 1.5; -- Weekend spike

        declare @DailyOrders int = @BaseOrders + (abs(checksum(newid())) % 5);
        declare @k int = 1;

        begin transaction; 
        while @k <= @DailyOrders
        begin
            insert into Orders (OrderDate, CustomerID, WarehouseID, TotalAmount, Status)
            values (@CurrentDate, 1 + (abs(checksum(newid())) % 1999), 1, 0, 'DELIVERED');
            
            declare @OrderID int = scope_identity();

            insert into OrderItems (OrderID, ProductID, Quantity, FinalPrice)
            select top (1 + (abs(checksum(newid())) % 3))
                @OrderID, ProductID, 1 + (abs(checksum(newid())) % 2), UnitPrice
            from Products order by newid(); 

            insert into InventoryLedger (WarehouseID, ProductID, QuantityChange, TransactionType, TransactionDate, ReferenceID)
            select 1, ProductID, -Quantity, 'SALE', @CurrentDate, @OrderID
            from OrderItems where OrderID = @OrderID;

            update Orders 
            set TotalAmount = (select sum(Quantity * FinalPrice) from OrderItems where OrderID = @OrderID) 
            where OrderID = @OrderID;

            set @k = @k + 1;
        end
        commit transaction;

        if day(@CurrentDate) = 1 and month(@CurrentDate) % 3 = 0
            raiserror('Symulacja trwa...', 0, 1) with nowait;

        set @CurrentDate = dateadd(day, 1, @CurrentDate);
    end

	-- 7. RETURNS SIMULATION
    -- Select ~8% of sales to be returned randomly.
    if object_id('tempdb..#ReturnsToProcess') is not null drop table #ReturnsToProcess;

    select top 8 percent
        l.ReferenceID as RefOrderID,
        l.TransactionDate as OriginalSaleDate,
        l.WarehouseID,
        l.ProductID,
        abs(l.QuantityChange) as QuantityToReturn,
        dateadd(day, 3 + (abs(checksum(newid())) % 14), l.TransactionDate) as ReturnDate
    into #ReturnsToProcess
    from InventoryLedger l
    where l.TransactionType = 'SALE'
    order by newid();

    delete from #ReturnsToProcess where ReturnDate > getdate();

    insert into InventoryLedger (WarehouseID, ProductID, QuantityChange, TransactionType, TransactionDate, ReferenceID)
    select WarehouseID, ProductID, QuantityToReturn, 'RETURN', ReturnDate, RefOrderID
    from #ReturnsToProcess;

    update Orders
    set Status = 'RETURNED'
    where OrderID in (select distinct RefOrderID from #ReturnsToProcess);

    drop table #ReturnsToProcess;

end
go


exec SimulateRetailActivity_Timeline;

-- 8. AD-HOC DATA ENRICHMENT
-- Adding specific "Dead Stock" items manually.
insert into Products (SKU, ProductName, BrandID, SupplierID, Category, UnitCost, UnitPrice, WeightKG, IsActive)
values 
('DS-001', 'Niechciany Gad¿et 2023', 1, 1, 'Electronics', 50.00, 120.00, 0.5, 1),
('DS-002', 'Stary Kalendarz 2024', 2, 1, 'Home', 15.00, 45.00, 0.2, 0),
('DS-003', 'Nietrafiona Kolekcja Lato', 3, 2, 'Fashion', 100.00, 250.00, 0.8, 1),
('DS-004', 'Wadliwa Partia S³uchawek', 1, 1, 'Electronics', 30.00, 99.00, 0.3, 1),
('DS-005', 'Ozdoby Œwi¹teczne (po sezonie)', 2, 3, 'Home', 10.00, 25.00, 0.1, 1);

-- Identifying dead products to initialize their stock
select ProductID, UnitCost 
into #DeadProducts
from Products 
where SKU like 'DS-%';

-- Adding stock for dead products
insert into InventoryLedger (WarehouseID, ProductID, QuantityChange, TransactionType, TransactionDate)
select 
    1,
    ProductID, 
    100, 
    'PURCHASE', 
    dateadd(day, -180, getdate())
from #DeadProducts;

drop table #DeadProducts;




