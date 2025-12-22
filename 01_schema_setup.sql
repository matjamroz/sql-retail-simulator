create database RetailDB;
go

use RetailDB;
go

create table Suppliers (
    SupplierID int identity(1,1) primary key,
    SupplierName varchar(100),
    Country varchar(50),
    LeadTimeDays int 
);

create table Brands (
    BrandID int identity(1,1) primary key,
    BrandName varchar(50),
    TargetAudience varchar(50) 
);

create table Warehouses (
    WarehouseID int identity(1,1) primary key,
    LocationName varchar(50),
    City varchar(50),
    Type varchar(20) 
);

create table Customers (
    CustomerID int identity(1,1) primary key,
    FirstName varchar(50),
    LastName varchar(50),
    Segment varchar(20),
    JoinDate datetime
);

create table Products (
    ProductID int identity(1,1) primary key,
    SKU varchar(30) unique,
    ProductName varchar(100),
    BrandID int foreign key references Brands(BrandID),
    SupplierID int foreign key references Suppliers(SupplierID),
    Category varchar(50),
    UnitCost decimal(10,2),
    UnitPrice decimal(10,2),
    WeightKG decimal(5,2),
    IsActive bit default 1
);

create table Orders (
    OrderID int identity(1,1) primary key,
    OrderDate datetime,
    CustomerID int foreign key references Customers(CustomerID),
    WarehouseID int, 
    TotalAmount decimal(12,2),
    Status varchar(20) 
);

create table OrderItems (
    OrderItemID int identity(1,1) primary key,
    OrderID int foreign key references Orders(OrderID),
    ProductID int foreign key references Products(ProductID),
    Quantity int,
    FinalPrice decimal(10,2) 
);

create table InventoryLedger (
    LedgerID bigint identity(1,1) primary key, 
    WarehouseID int foreign key references Warehouses(WarehouseID),
    ProductID int foreign key references Products(ProductID),
    QuantityChange int, -- (+/-)
    TransactionType varchar(50), 
    TransactionDate datetime,
    ReferenceID int null 
);
go

-- PERFORMANCE INDEXES
-- Fast lookup for customer orders
create nonclustered index IX_Orders_CustomerID 
on Orders(CustomerID) include (TotalAmount, OrderDate);

-- Reporting by dates
create nonclustered index IX_InventoryLedger_TransactionDate 
on InventoryLedger(TransactionDate) include (TransactionType, QuantityChange);

-- Fast join between products and ledger
create nonclustered index IX_InventoryLedger_ProductID 
on InventoryLedger(ProductID) include (WarehouseID);

-- Product lookup by SKU 
create nonclustered index IX_Products_SKU 
on Products(SKU);
go

-- APPLYING CONSTRAINTS
-- Ensuring data integrity after the simulation.
alter table Products 
add constraint CK_Products_Price check (UnitPrice >= 0 and UnitCost >= 0);

alter table OrderItems 
add constraint CK_OrderItems_Quantity check (Quantity > 0);
