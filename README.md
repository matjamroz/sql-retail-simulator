

*English below*


# RetailDB: Symulacja Handlu Detalicznego i Analityka SQL

Ten projekt to środowisko SQL Server symulujące działanie firmy z branży retail. Projekt generuje schemat bazy danych, symuluje 2 lata historii transakcyjnejoraz tworzy warstwę analityczną .

## Struktura Plików

Należy wykonywać skrypty w ściśle określonej kolejności ze względu na zależności obiektów.

1.  **`01_schema_setup.sql`**
    * Tworzy bazę danych `RetailDB` oraz strukturę tabel.
    * Definiuje klucze obce, ograniczenia oraz indeksy wydajnościowe.

2.  **`02_data_generation.sql`**
    * Zawiera główną procedurę `SimulateRetailActivity_Timeline`.
    * Generuje dane statyczne: 2000 klientów, 500 produktów, dostawców i magazyny.
    * **Symulator:** Iteruje dzień po dniu przez ostatnie 2 lata, generując zamówienia z uwzględnieniem sezonowości.
    * Symuluje proces zwrotów oraz tworzy sztuczny "Dead Stock".

3.  **`03_analytics.sql`**
    * Tworzy warstwę analityczną składającą się z widoków oraz procedur raportowych.
    * Zawiera analizy biznesowe.

## Kluczowe Funkcjonalności Analityczne

Projekt implementuje szereg standardowych metryk biznesowych używanych w e-commerce i handlu detalicznym:

* **Segmentacja Klientów (RFM):** Klasyfikacja klientów na grupy na podstawie czasu od ostatniego zakupu, częstotliwości i wartości koszyka.
* **Analiza Koszykowa (Market Basket):** Identyfikacja produktów najczęściej kupowanych w parach, przydatna do cross-sellingu.
* **Zarządzanie Zapasami:**
    * **Dead Stock Alerts:** Wykrywanie produktów zalegających w magazynie powyżej 90 dni.
    * **Klasyfikacja:** Podział produktów na grupy A/B/C według generowanego przychodu.
* **KPI Dashboard:** Dzienny raport przychodów, marży, kosztów oraz wskaźnika zwrotów.
* **Analiza Trendów:** Wykrywanie anomalii sprzedażowych przy użyciu tygodniowej średniej kroczącej.

## Instrukcja Uruchomienia

1.  `01_schema_setup.sql`
2.  `02_data_generation.sql`
3.  `03_analytics.sql`




# RetailDB: Retail Simulation & SQL Analytics

This project creates a SQL Server environment simulating a retail company. It generates the database schema, simulates 2 years of transactional history, and builds an analytics layer.

## File Structure

Scripts must be executed in a specific order due to object dependencies.

1.  **`01_schema_setup.sql`**
    * Creates the `RetailDB` database and table structure.
    * Defines foreign keys, constraints, and performance indexes.

2.  **`02_data_generation.sql`**
    * Contains the main procedure `SimulateRetailActivity_Timeline`.
    * Generates static data: 2000 customers, 500 products, suppliers, and warehouses.
    * **Simulator:** Iterates day-by-day through the last 2 years, generating orders with seasonality logic.
    * Simulates returns and artificially creates "Dead Stock" items.

3.  **`03_analytics.sql`**
    * Creates the analytics layer consisting of Views and reporting procedures.
    * Includes business analysis.

## Key Analytics Features

The project implements standard business metrics used in e-commerce and retail:

* **Customer Segmentation (RFM):** Classifies customers based on Recency, Frequency, and Monetary value.
* **Market Basket Analysis:** Identifies product pairs frequently purchased together, useful for cross-selling strategies.
* **Inventory Management:**
    * **Dead Stock Alerts:** Detects products that have not moved from the warehouse for over 90 days.
    * **ABC Classification:** Segments products into A/B/C groups based on revenue generated.
* **KPI Dashboard:** Daily report of revenue, margins, COGS, and return rates.
* **Trend Analysis:** Detects sales anomalies using a 7-day moving average.

## Usage Instructions

1.  `01_schema_setup.sql`
2.  `02_data_generation.sql`
3.  `03_analytics.sql`
