# Review 2 — Full Database Implementation Report
### Car Rental Reservation & Vehicle Return Management System

Companion document to `car_rental_review2.sql`. This covers everything that isn't code: the normalization argument, functional dependencies, data dictionary, rule-to-mechanism mapping, transaction/indexing rationale, the live demo script, and viva prep. **The SQL file has been executed end-to-end against a real MySQL/MariaDB instance with zero errors** — every business rule below was individually tested and confirmed to reject bad data with the right error message.

---

## PART 1 — Normalization: 1NF -> 2NF -> 3NF, table by table

**Quick definitions to open with, if asked:**
- **1NF**: every column holds a single atomic value, no repeating groups.
- **2NF**: 1NF, plus every non-key attribute depends on the *whole* primary key (only matters for tables with a composite key — all 11 tables here use a single-column surrogate key, so 2NF is automatically satisfied once 1NF holds).
- **3NF**: 2NF, plus no non-key attribute depends on another non-key attribute (no transitive dependency).

| Table | Candidate Key(s) | Primary Key | Why it's in 3NF |
|---|---|---|---|
| Branch | branch_id | branch_id | All columns (name, city, address, phone) describe the branch directly — nothing transitive. |
| VehicleCategory | category_id, category_name (UK) | category_id | description depends only on category_id. |
| Vehicle | vehicle_id, registration_no (UK) | vehicle_id | We deliberately do not store category_name or branch_name here — only the FKs. Storing them would create a transitive dependency (vehicle_id -> category_id -> category_name), which is exactly what 3NF forbids. |
| Customer | customer_id, phone (UK), email (UK), license_no (UK) | customer_id | All attributes (name, dob, contact, licence) describe the customer atomically. |
| RatePlan | rate_plan_id | rate_plan_id | Rates depend on rate_plan_id, not on category_id alone — a category can have more than one plan, so this isn't collapsible into VehicleCategory. |
| Reservation | reservation_id | reservation_id | customer_id, category_id, branch ids are independent FKs; no attribute here depends on another non-key attribute. |
| Rental | rental_id | rental_id | This is the deepest table (6 FKs) but every FK is an independent fact about the rental — vehicle_id doesn't determine customer_id or vice versa. |
| Inspection | inspection_id | inspection_id | odometer_reading and fuel_level_percent depend only on inspection_id, not on each other. |
| Damage | damage_id | damage_id | repair_cost and charged_amount are independent facts about one damage event. |
| Invoice | invoice_id, rental_id (UK) | invoice_id | Each charge column (base_charge, extra_km_charge, etc.) is an independent component of the bill — none derives from another non-key column. |
| Payment | payment_id | payment_id | amount, mode, and reference are independent facts about one payment. |

**The one deliberate normalization judgment call to be ready to defend:** fuel readings aren't a separate table. A fuel reading only exists in the context of one Inspection event — it has no independent existence — so making it its own table would just be a 1:1 relationship with Inspection for no benefit (over-normalization). It's a plain column (`fuel_level_percent`) on Inspection instead.

---

## PART 2 — Functional Dependencies

```
Branch:       branch_id -> branch_name, city, address, phone
VehicleCategory: category_id -> category_name, description
Vehicle:      vehicle_id -> registration_no, category_id, branch_id, make, model, year, color, current_odometer, status
Customer:     customer_id -> full_name, dob, phone, email, license_no, license_expiry, address
RatePlan:     rate_plan_id -> category_id, plan_name, daily_rate, weekly_rate, extra_km_rate, late_fee_per_hour
Reservation:  reservation_id -> customer_id, category_id, pickup_branch_id, return_branch_id, pickup_date, expected_return_date, status
Rental:       rental_id -> reservation_id, vehicle_id, customer_id, rate_plan_id, pickup_branch_id, return_branch_id,
                          pickup_datetime, expected_return_datetime, actual_return_datetime, status
Inspection:   inspection_id -> rental_id, inspection_type, inspection_datetime, odometer_reading, fuel_level_percent,
                              exterior_condition, notes, inspected_by
Damage:       damage_id -> rental_id, inspection_id, description, repair_cost, charged_amount
Invoice:      invoice_id -> rental_id, invoice_date, base_charge, extra_km_charge, late_fee, damage_charge, tax_amount, total_amount
Payment:      payment_id -> invoice_id, payment_date, amount, payment_mode, transaction_ref
```

**How these support 3NF:** in every table above, the determinant on the left is the *whole* primary key, and everything on the right depends on it directly — never on another attribute on the right. That's the definition of 3NF applied literally. The clearest illustration is Vehicle: `vehicle_id -> category_id` is a real FD, but there is **no** FD `vehicle_id -> category_name` stored directly — that would only be reachable transitively via category_id, so we don't store it. That's the difference between a normalized and an unnormalized design in one sentence.

---

## PART 3 — Data Dictionary (concise, PPT-ready)

### Branch
| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| branch_id | INT | PK | NOT NULL | AUTO_INCREMENT | Unique branch identifier |
| branch_name | VARCHAR(80) | | NOT NULL | | Display name |
| city | VARCHAR(50) | | NOT NULL | | City |
| address | VARCHAR(150) | | NULL | | Street address |
| phone | VARCHAR(15) | | NOT NULL | | Contact number |

### VehicleCategory
| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| category_id | INT | PK | NOT NULL | AUTO_INCREMENT | Unique category id |
| category_name | VARCHAR(40) | UK | NOT NULL | | Economy/Sedan/SUV/Luxury |
| description | VARCHAR(150) | | NULL | | Free text |

### Vehicle
| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| vehicle_id | INT | PK | NOT NULL | AUTO_INCREMENT | Unique vehicle id |
| registration_no | VARCHAR(15) | UK | NOT NULL | | Number plate |
| category_id | INT | FK->VehicleCategory | NOT NULL | | Category |
| branch_id | INT | FK->Branch | NOT NULL | | Home branch |
| make, model | VARCHAR(40) | | NOT NULL | | |
| year | INT | | NOT NULL | | CHECK 1990-2100 |
| color | VARCHAR(20) | | NULL | | |
| current_odometer | INT | | NOT NULL | 0 | CHECK >= 0 |
| status | VARCHAR(15) | | NOT NULL | 'Available' | CHECK IN (Available, Rented, Maintenance, Retired) |

### Customer
| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| customer_id | INT | PK | NOT NULL | AUTO_INCREMENT | |
| full_name | VARCHAR(80) | | NOT NULL | | |
| dob | DATE | | NOT NULL | | |
| phone | VARCHAR(15) | UK | NOT NULL | | |
| email | VARCHAR(80) | UK | NULL | | |
| license_no | VARCHAR(20) | UK | NOT NULL | | |
| license_expiry | DATE | | NOT NULL | | Checked by trigger at pickup |
| address | VARCHAR(150) | | NULL | | |

### RatePlan
| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| rate_plan_id | INT | PK | NOT NULL | AUTO_INCREMENT | |
| category_id | INT | FK->VehicleCategory | NOT NULL | | |
| plan_name | VARCHAR(40) | | NOT NULL | | |
| daily_rate, weekly_rate | DECIMAL(10,2) | | NOT NULL | | CHECK > 0 |
| extra_km_rate, late_fee_per_hour | DECIMAL(6,2) | | NOT NULL | 0 | CHECK >= 0 |

### Reservation
| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| reservation_id | INT | PK | NOT NULL | AUTO_INCREMENT | |
| customer_id | INT | FK->Customer | NOT NULL | | |
| category_id | INT | FK->VehicleCategory | NOT NULL | | |
| pickup_branch_id, return_branch_id | INT | FK->Branch | NOT NULL | | Two separate FKs to the same table (one-way rentals) |
| reservation_date | DATETIME | | NOT NULL | CURRENT_TIMESTAMP | |
| pickup_date, expected_return_date | DATETIME | | NOT NULL | | CHECK return > pickup |
| status | VARCHAR(15) | | NOT NULL | 'Booked' | CHECK IN (Booked, Cancelled, Completed, Converted) |

### Rental
| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| rental_id | INT | PK | NOT NULL | AUTO_INCREMENT | |
| reservation_id | INT | FK->Reservation | NULL | | Nullable — walk-ins have none |
| vehicle_id | INT | FK->Vehicle | NOT NULL | | |
| customer_id | INT | FK->Customer | NOT NULL | | |
| rate_plan_id | INT | FK->RatePlan | NOT NULL | | |
| pickup_branch_id, return_branch_id | INT | FK->Branch | NOT NULL | | |
| pickup_datetime, expected_return_datetime | DATETIME | | NOT NULL | | CHECK return > pickup |
| actual_return_datetime | DATETIME | | NULL | | CHECK > pickup_datetime when present |
| status | VARCHAR(15) | | NOT NULL | 'Active' | CHECK IN (Active, Returned, Overdue) |

### Inspection
| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| inspection_id | INT | PK | NOT NULL | AUTO_INCREMENT | |
| rental_id | INT | FK->Rental | NOT NULL | | |
| inspection_type | VARCHAR(10) | | NOT NULL | | CHECK IN (Pickup, Return) |
| inspection_datetime | DATETIME | | NOT NULL | CURRENT_TIMESTAMP | |
| odometer_reading | INT | | NOT NULL | | CHECK >= 0; return >= pickup via trigger |
| fuel_level_percent | INT | | NOT NULL | | CHECK 0-100 |
| exterior_condition | VARCHAR(20) | | NULL | 'Good' | |
| notes | VARCHAR(200) | | NULL | | |
| inspected_by | VARCHAR(60) | | NULL | | Staff name |

### Damage
| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| damage_id | INT | PK | NOT NULL | AUTO_INCREMENT | |
| rental_id | INT | FK->Rental | NOT NULL | | |
| inspection_id | INT | FK->Inspection | NULL | | Which inspection found it |
| description | VARCHAR(200) | | NOT NULL | | |
| repair_cost, charged_amount | DECIMAL(10,2) | | NOT NULL | 0 | CHECK >= 0 |

### Invoice
| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| invoice_id | INT | PK | NOT NULL | AUTO_INCREMENT | |
| rental_id | INT | FK->Rental, UK | NOT NULL | | 1:1 with Rental |
| invoice_date | DATETIME | | NOT NULL | CURRENT_TIMESTAMP | |
| base_charge, extra_km_charge, late_fee, damage_charge, tax_amount, total_amount | DECIMAL(10,2) | | NOT NULL | 0 (except total) | All CHECK >= 0 |

### Payment
| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| payment_id | INT | PK | NOT NULL | AUTO_INCREMENT | |
| invoice_id | INT | FK->Invoice | NOT NULL | | One invoice, many payments |
| payment_date | DATETIME | | NOT NULL | CURRENT_TIMESTAMP | |
| amount | DECIMAL(10,2) | | NOT NULL | | CHECK > 0 |
| payment_mode | VARCHAR(15) | | NOT NULL | | CHECK IN (Cash, Card, UPI, NetBanking) |
| transaction_ref | VARCHAR(40) | | NULL | | |

---

## PART 5 — Business Rules -> Enforcement Mechanism (tested and confirmed working)

| # | Rule | Mechanism | Why | Confirmed error |
|---|---|---|---|---|
| 1 | No overlapping rentals | **Trigger** (`trg_no_overlap_rental`, BEFORE INSERT) | Must compare the new rental against *other existing rows* for the same vehicle — a CHECK constraint can only see the row being written, never other rows. | `Error 1644 (45000): Vehicle already has an overlapping active rental` |
| 2 | Valid driving licence | **Trigger** (`trg_valid_license`, BEFORE INSERT) | Must look up the customer's `license_expiry` in a *different table* — CHECK constraints cannot reference another table at all. | `Error 1644 (45000): Customer driving license has expired` |
| 3 | Return after pickup | **CHECK constraint** | Both columns being compared (`pickup_datetime`, `actual_return_datetime`) live in the *same row* — no cross-row lookup needed. | `Error 4025 (23000): CONSTRAINT ... failed` |
| 4 | Valid odometer / fuel readings | **CHECK + Trigger** | Fuel range (0-100) is single-row -> CHECK. Comparing return odometer against the *pickup row's* odometer is cross-row -> trigger (`trg_valid_odometer`). | `Error 1644 (45000): Return odometer reading cannot be less than pickup reading` |
| 5 | Non-negative charges | **CHECK constraint** | Single-column, single-row comparison against a literal (`amount > 0`, `total_amount >= 0`). | `Error 4025 (23000): CONSTRAINT 'Payment.amount' failed` |

**One-sentence answer for "why can't CHECK alone do rule 1 or 2":** a CHECK constraint in MySQL is evaluated against the columns of the single row being inserted or updated — it has no mechanism to run a query against other rows or other tables, which is exactly what overlap detection and licence lookup both require.

Two supporting triggers keep `Vehicle.status` synced automatically (set to `'Rented'` right after a Rental is inserted, and back to `'Available'` the moment `actual_return_datetime` is filled in on UPDATE) — not a graded business rule, but it's what makes the Fleet Availability report accurate without a manual status update step.

---

## PART 9 — Transactions

**Why a transaction is needed for issuing a rental:** three things have to happen together — insert the Rental row, insert the pickup Inspection, and (via the AFTER INSERT trigger) flip the vehicle to `'Rented'`. If the Inspection insert failed partway, we don't want a Rental to exist with no pickup record. Wrapping it in `START TRANSACTION ... COMMIT` makes it all-or-nothing.

```sql
START TRANSACTION;
INSERT INTO Rental (...) VALUES (...);
SET @new_rental_id = LAST_INSERT_ID();
INSERT INTO Inspection (rental_id, inspection_type, ...) VALUES (@new_rental_id, 'Pickup', ...);
COMMIT;
```

**Rollback example, and the nuance worth knowing for viva:** in MySQL/InnoDB, a single statement that fails a CHECK constraint or trigger **does not automatically roll back the whole transaction** — unlike a deadlock, it's just that one statement that's rejected; everything else already run in that transaction is still sitting there, uncommitted. It's the application's job to notice the failure and explicitly issue `ROLLBACK`. The script demonstrates this: a valid Payment insert followed by a deliberately-invalid one — since the two were meant to be recorded together and one failed, we `ROLLBACK` the valid one too, rather than leaving a half-finished operation committed. This was verified: after the rollback, `SELECT * FROM Payment WHERE transaction_ref='TXN_DEMO_STEP1'` returns zero rows.

---

## PART 10 — Indexing Rationale

| Index | Column(s) | Why |
|---|---|---|
| idx_vehicle_regno | Vehicle.registration_no | Staff look up a vehicle by plate at pickup/return |
| idx_vehicle_status | Vehicle.status | Every availability search filters `WHERE status='Available'` |
| idx_vehicle_category | Vehicle.category_id | Availability search is usually "by category" |
| idx_customer_license | Customer.license_no | Checked by the licence-validity trigger on every rental issue |
| idx_customer_phone / idx_customer_email | Customer | Front-desk staff search customers by phone/email |
| idx_rental_dates | Rental(pickup_datetime, expected_return_datetime) | The overlap trigger and overdue report both filter/compare on these |
| idx_rental_status | Rental.status | Active/Overdue dashboards filter on this constantly |
| idx_rental_vehicle | Rental.vehicle_id | The overlap trigger's subquery scans by vehicle_id on every insert |
| idx_reservation_dates | Reservation(pickup_date, expected_return_date) | Same reasoning as rental dates |
| idx_invoice_rental | Invoice.rental_id | Already UNIQUE, indexed explicitly for join clarity |

Each index was added because a *named query above actually filters or joins on that column* — not speculatively. That's the answer if asked "why these and not more."

---

## Live Demo Script (Part 11 — run in this order)

1. `SHOW DATABASES;` / `SHOW TABLES;` — database and 11 tables exist
2. `DESCRIBE Rental;` — show PK/FK/constraints on one non-trivial table
3. `SELECT * FROM vw_fleet_availability;` — sample records + a view together
4. Run the **successful transaction** block (Part 9A) live — `SELECT * FROM Rental ORDER BY rental_id DESC LIMIT 1;` to show it landed
5. Run the **rollback** block (Part 9B) — then `SELECT * FROM Payment WHERE transaction_ref='TXN_DEMO_STEP1';` to prove it rolled back (zero rows)
6. Run **each** commented-out rejection in Part 11 one at a time — negative payment, return-before-pickup, overlapping rental, expired licence, bad odometer — showing the exact error each time
7. Run one join (A1), one subquery (B1), one aggregate (C2), and one view (`vw_branch_revenue`)
8. Finish on the **Branch Revenue** and **Overdue Rentals** reports as the "so what" — this is what the database is actually for

---

## PART 13 — Viva Preparation

**What is DBMS?**
Software that lets you store, organize, and query structured data reliably, enforcing rules (like uniqueness or valid ranges) that a plain file or spreadsheet can't enforce on its own.

**Why MySQL?**
Free, widely used, strong constraint/trigger/view support, and good Java/Python connector support — everything this project needs.

**What is 3NF?**
No non-key column depends on another non-key column — only on the primary key, directly.

**What is a functional dependency?**
A rule of the form "if you know X, you always know Y" — e.g., knowing vehicle_id tells you its registration number, because each vehicle has exactly one.

**Why is the database in 3NF?**
Every table's non-key columns describe only that table's entity directly. The clearest proof: Vehicle doesn't store category_name — only category_id — because category_name depends on category_id, not on vehicle_id.

**Primary key? Foreign key?**
PK uniquely identifies a row and can't be null or duplicated. FK references another table's PK, so you can't insert a row pointing at something that doesn't exist.

**Difference between Reservation and Rental?**
Reservation is an advance booking for a category — no vehicle assigned yet. Rental is the real transaction — a specific vehicle physically issued. A Rental's link back to Reservation is optional because walk-ins skip the reservation step entirely.

**Why is Inspection separate from Rental?**
A rental gets *two* inspection events (pickup and return) that share the same shape (odometer, fuel, condition) — modeling them as rows of one Inspection entity avoids duplicating those columns twice inside Rental, and leaves room for a third inspection type later without a schema change.

**Why is Damage separate from Inspection?**
Not every inspection finds damage, and one inspection could in principle note more than one distinct damage item — keeping Damage as its own table with a nullable FK to Inspection keeps that relationship honest instead of cramming a variable number of damage notes into fixed columns.

**Why is RatePlan separate from VehicleCategory?**
A category can have more than one active pricing plan (e.g., a weekend promo alongside the standard rate), and historical rentals need to stay linked to whatever rate was active *then*, not to today's price.

**Why is Invoice separate from Payment?**
One invoice can be paid in multiple installments — that's a genuine 1:M relationship, demonstrated in the sample data where invoice 2 has two partial payments.

**Why can't overlapping rentals be handled using only CHECK?**
A CHECK constraint only ever sees the row currently being written — it has no way to query other existing rows in the table. Overlap detection needs exactly that: comparing the new booking against every *other* rental of the same vehicle. That requires a trigger.

**What is a trigger?**
A stored procedure that MySQL runs automatically before or after an INSERT/UPDATE/DELETE on a table — used here to enforce rules that need to look beyond the single row being written.

**What is referential integrity?**
The guarantee that a foreign key value always points to a row that actually exists in the referenced table — MySQL blocks any insert/update that would violate this.

**What is a transaction? Why COMMIT/ROLLBACK?**
A group of statements that succeed or fail as one unit. COMMIT makes the group permanent; ROLLBACK undoes everything in the group if something went wrong partway — needed here because issuing a rental touches three things (Rental, Inspection, Vehicle status) that must all land together.

**What is an index? WHERE vs. HAVING?**
An index is a lookup structure that speeds up searching/filtering on a column, at the cost of extra storage and slightly slower writes. WHERE filters individual rows *before* grouping; HAVING filters *groups* after `GROUP BY` — e.g., you can't say `WHERE COUNT(*) > 5` but you can say `HAVING COUNT(*) > 5`.

**JOIN vs. subquery?**
A JOIN combines rows from two tables side by side in one result set. A subquery is a query nested inside another, typically used to compute a single value (like an average) that the outer query then compares against.

**What is a view?**
A saved SELECT statement that behaves like a virtual table — used here so the app and reports can just `SELECT * FROM vw_fleet_availability` instead of repeating the same three-way join everywhere.

**How is vehicle availability determined? Overdue rentals? Branch revenue? Utilization?**
Availability: `Vehicle.status = 'Available'`, kept in sync by triggers. Overdue: `actual_return_datetime IS NULL AND expected_return_datetime < NOW()`. Branch revenue: `SUM(Invoice.total_amount)` grouped by the rental's pickup branch. Utilization: count of rentals and total days rented per vehicle, from a LEFT JOIN so even never-rented vehicles show up with zero.

**How does the system prevent invalid data overall?**
Layered: data types + NOT NULL stop malformed/missing input, UNIQUE stops duplicates, CHECK stops out-of-range single-row values, foreign keys stop orphaned references, and triggers catch everything that needs to look across rows or tables. No single mechanism does it all — that's the point of using several together.
