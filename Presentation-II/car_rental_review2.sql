-- =====================================================================
-- CAR RENTAL RESERVATION AND VEHICLE RETURN MANAGEMENT SYSTEM
-- DBMS PBL - Project 19 - REVIEW 2: Full Database Implementation
-- Dialect: MySQL 8.x
-- Run top to bottom in MySQL Workbench / CLI. Order matters (FK dependencies).
-- =====================================================================

DROP DATABASE IF EXISTS car_rental_db;
CREATE DATABASE car_rental_db;
USE car_rental_db;

-- =====================================================================
-- PART 4 — TABLES  (PK, FK, UNIQUE, NOT NULL, CHECK, DEFAULT, ON DELETE/UPDATE)
-- =====================================================================

CREATE TABLE Branch (
    branch_id     INT AUTO_INCREMENT PRIMARY KEY,
    branch_name   VARCHAR(80)  NOT NULL,
    city          VARCHAR(50)  NOT NULL,
    address       VARCHAR(150),
    phone         VARCHAR(15)  NOT NULL
);

CREATE TABLE VehicleCategory (
    category_id     INT AUTO_INCREMENT PRIMARY KEY,
    category_name   VARCHAR(40) NOT NULL UNIQUE,
    description     VARCHAR(150)
);

-- Vehicle: category_id/branch_id use RESTRICT so a category or branch with
-- vehicles still assigned to it can't be deleted out from under them.
CREATE TABLE Vehicle (
    vehicle_id       INT AUTO_INCREMENT PRIMARY KEY,
    registration_no  VARCHAR(15) NOT NULL UNIQUE,
    category_id      INT NOT NULL,
    branch_id        INT NOT NULL,
    make             VARCHAR(40) NOT NULL,
    model            VARCHAR(40) NOT NULL,
    year             INT NOT NULL CHECK (year BETWEEN 1990 AND 2100),
    color            VARCHAR(20),
    current_odometer INT NOT NULL DEFAULT 0 CHECK (current_odometer >= 0),
    status           VARCHAR(15) NOT NULL DEFAULT 'Available'
                       CHECK (status IN ('Available','Rented','Maintenance','Retired')),
    FOREIGN KEY (category_id) REFERENCES VehicleCategory(category_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (branch_id)   REFERENCES Branch(branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Customer (
    customer_id     INT AUTO_INCREMENT PRIMARY KEY,
    full_name       VARCHAR(80) NOT NULL,
    dob             DATE NOT NULL,
    phone           VARCHAR(15) NOT NULL UNIQUE,
    email           VARCHAR(80) UNIQUE,
    license_no      VARCHAR(20) NOT NULL UNIQUE,
    license_expiry  DATE NOT NULL,
    address         VARCHAR(150)
);

CREATE TABLE RatePlan (
    rate_plan_id      INT AUTO_INCREMENT PRIMARY KEY,
    category_id       INT NOT NULL,
    plan_name         VARCHAR(40) NOT NULL,
    daily_rate        DECIMAL(10,2) NOT NULL CHECK (daily_rate > 0),
    weekly_rate       DECIMAL(10,2) NOT NULL CHECK (weekly_rate > 0),
    extra_km_rate     DECIMAL(6,2)  NOT NULL DEFAULT 0 CHECK (extra_km_rate >= 0),
    late_fee_per_hour DECIMAL(6,2)  NOT NULL DEFAULT 0 CHECK (late_fee_per_hour >= 0),
    FOREIGN KEY (category_id) REFERENCES VehicleCategory(category_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Reservation (
    reservation_id       INT AUTO_INCREMENT PRIMARY KEY,
    customer_id          INT NOT NULL,
    category_id          INT NOT NULL,
    pickup_branch_id     INT NOT NULL,
    return_branch_id     INT NOT NULL,
    reservation_date     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    pickup_date          DATETIME NOT NULL,
    expected_return_date DATETIME NOT NULL,
    status               VARCHAR(15) NOT NULL DEFAULT 'Booked'
                           CHECK (status IN ('Booked','Cancelled','Completed','Converted')),
    FOREIGN KEY (customer_id)      REFERENCES Customer(customer_id)      ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (category_id)      REFERENCES VehicleCategory(category_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (pickup_branch_id) REFERENCES Branch(branch_id)          ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (return_branch_id) REFERENCES Branch(branch_id)          ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (expected_return_date > pickup_date)
);

-- Rental: reservation_id is nullable (walk-ins have no reservation) and uses
-- ON DELETE SET NULL - deleting a reservation should not destroy the rental
-- that came from it, only unlink it.
CREATE TABLE Rental (
    rental_id                 INT AUTO_INCREMENT PRIMARY KEY,
    reservation_id            INT NULL,
    vehicle_id                INT NOT NULL,
    customer_id               INT NOT NULL,
    rate_plan_id              INT NOT NULL,
    pickup_branch_id          INT NOT NULL,
    return_branch_id          INT NOT NULL,
    pickup_datetime           DATETIME NOT NULL,
    expected_return_datetime  DATETIME NOT NULL,
    actual_return_datetime    DATETIME NULL,
    status                    VARCHAR(15) NOT NULL DEFAULT 'Active'
                                CHECK (status IN ('Active','Returned','Overdue')),
    FOREIGN KEY (reservation_id)   REFERENCES Reservation(reservation_id) ON DELETE SET NULL  ON UPDATE CASCADE,
    FOREIGN KEY (vehicle_id)       REFERENCES Vehicle(vehicle_id)         ON DELETE RESTRICT  ON UPDATE CASCADE,
    FOREIGN KEY (customer_id)      REFERENCES Customer(customer_id)       ON DELETE RESTRICT  ON UPDATE CASCADE,
    FOREIGN KEY (rate_plan_id)     REFERENCES RatePlan(rate_plan_id)      ON DELETE RESTRICT  ON UPDATE CASCADE,
    FOREIGN KEY (pickup_branch_id) REFERENCES Branch(branch_id)           ON DELETE RESTRICT  ON UPDATE CASCADE,
    FOREIGN KEY (return_branch_id) REFERENCES Branch(branch_id)           ON DELETE RESTRICT  ON UPDATE CASCADE,
    CHECK (actual_return_datetime IS NULL OR actual_return_datetime > pickup_datetime),
    CHECK (expected_return_datetime > pickup_datetime)
);

-- Inspection/Damage are "detail" records with no independent meaning apart
-- from their Rental, so they CASCADE if a rental is ever purged.
CREATE TABLE Inspection (
    inspection_id       INT AUTO_INCREMENT PRIMARY KEY,
    rental_id            INT NOT NULL,
    inspection_type       VARCHAR(10) NOT NULL CHECK (inspection_type IN ('Pickup','Return')),
    inspection_datetime     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    odometer_reading           INT NOT NULL CHECK (odometer_reading >= 0),
    fuel_level_percent           INT NOT NULL CHECK (fuel_level_percent BETWEEN 0 AND 100),
    exterior_condition             VARCHAR(20) DEFAULT 'Good',
    notes                             VARCHAR(200),
    inspected_by                        VARCHAR(60),
    FOREIGN KEY (rental_id) REFERENCES Rental(rental_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Damage (
    damage_id      INT AUTO_INCREMENT PRIMARY KEY,
    rental_id        INT NOT NULL,
    inspection_id      INT NULL,
    description           VARCHAR(200) NOT NULL,
    repair_cost              DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (repair_cost >= 0),
    charged_amount              DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (charged_amount >= 0),
    FOREIGN KEY (rental_id)     REFERENCES Rental(rental_id)         ON DELETE CASCADE  ON UPDATE CASCADE,
    FOREIGN KEY (inspection_id) REFERENCES Inspection(inspection_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- Invoice/Payment are financial records - deliberately RESTRICT, never
-- CASCADE, so billing history can't be destroyed by deleting a rental.
CREATE TABLE Invoice (
    invoice_id       INT AUTO_INCREMENT PRIMARY KEY,
    rental_id           INT NOT NULL UNIQUE,
    invoice_date           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    base_charge               DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (base_charge >= 0),
    extra_km_charge              DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (extra_km_charge >= 0),
    late_fee                        DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (late_fee >= 0),
    damage_charge                      DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (damage_charge >= 0),
    tax_amount                            DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
    total_amount                             DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0),
    FOREIGN KEY (rental_id) REFERENCES Rental(rental_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Payment (
    payment_id     INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id       INT NOT NULL,
    payment_date        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    amount                  DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    payment_mode               VARCHAR(15) NOT NULL CHECK (payment_mode IN ('Cash','Card','UPI','NetBanking')),
    transaction_ref                VARCHAR(40),
    FOREIGN KEY (invoice_id) REFERENCES Invoice(invoice_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- =====================================================================
-- PART 10 — INDEXES
-- Each index targets a column that is filtered/joined on in a frequent,
-- named query below - not added speculatively.
-- =====================================================================
CREATE INDEX idx_vehicle_regno      ON Vehicle(registration_no);   -- lookup by plate at pickup/return
CREATE INDEX idx_vehicle_status     ON Vehicle(status);            -- "available fleet" filters on this every search
CREATE INDEX idx_vehicle_category   ON Vehicle(category_id);       -- availability search is usually by category
CREATE INDEX idx_customer_license   ON Customer(license_no);       -- licence validated on every rental issue
CREATE INDEX idx_customer_phone     ON Customer(phone);            -- staff look customers up by phone at the counter
CREATE INDEX idx_customer_email     ON Customer(email);
CREATE INDEX idx_rental_dates       ON Rental(pickup_datetime, expected_return_datetime); -- overlap + overdue checks
CREATE INDEX idx_rental_status      ON Rental(status);             -- overdue/active dashboards filter on this
CREATE INDEX idx_rental_vehicle     ON Rental(vehicle_id);         -- overlap trigger scans by vehicle_id
CREATE INDEX idx_reservation_dates  ON Reservation(pickup_date, expected_return_date);
CREATE INDEX idx_invoice_rental     ON Invoice(rental_id);         -- already UNIQUE, but explicit for join clarity

-- =====================================================================
-- PART 5 — TRIGGERS (cross-row business rules a plain CHECK cannot express)
-- A CHECK constraint in MySQL can only look at columns of the SAME row
-- being written - it has no way to query other existing rows. Overlap
-- detection and licence validity both require comparing the new row
-- against OTHER rows (other rentals of the same vehicle; the customer's
-- own licence_expiry in a different table) so they must be triggers.
-- =====================================================================

DELIMITER //

-- Rule: no overlapping rentals for the same vehicle
CREATE TRIGGER trg_no_overlap_rental
BEFORE INSERT ON Rental
FOR EACH ROW
BEGIN
    DECLARE overlap_count INT;
    SELECT COUNT(*) INTO overlap_count
    FROM Rental
    WHERE vehicle_id = NEW.vehicle_id
      AND status IN ('Active','Overdue')
      AND pickup_datetime < NEW.expected_return_datetime
      AND expected_return_datetime > NEW.pickup_datetime;

    IF overlap_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Vehicle already has an overlapping active rental';
    END IF;
END//

-- Rule: customer licence must be valid (not expired) at pickup
CREATE TRIGGER trg_valid_license
BEFORE INSERT ON Rental
FOR EACH ROW
BEGIN
    DECLARE expiry DATE;
    SELECT license_expiry INTO expiry FROM Customer WHERE customer_id = NEW.customer_id;
    IF expiry < DATE(NEW.pickup_datetime) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Customer driving license has expired';
    END IF;
END//

-- Rule: valid odometer readings - return odometer cannot be less than the
-- pickup odometer reading for the same rental (cross-row within Inspection)
CREATE TRIGGER trg_valid_odometer
BEFORE INSERT ON Inspection
FOR EACH ROW
BEGIN
    DECLARE pickup_odo INT;
    IF NEW.inspection_type = 'Return' THEN
        SELECT odometer_reading INTO pickup_odo
        FROM Inspection
        WHERE rental_id = NEW.rental_id AND inspection_type = 'Pickup'
        LIMIT 1;
        IF pickup_odo IS NOT NULL AND NEW.odometer_reading < pickup_odo THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Return odometer reading cannot be less than pickup reading';
        END IF;
    END IF;
END//

-- Keep Vehicle.status in sync automatically with Rental lifecycle
CREATE TRIGGER trg_vehicle_status_on_issue
AFTER INSERT ON Rental
FOR EACH ROW
BEGIN
    UPDATE Vehicle SET status = 'Rented' WHERE vehicle_id = NEW.vehicle_id;
END//

CREATE TRIGGER trg_vehicle_status_on_return
AFTER UPDATE ON Rental
FOR EACH ROW
BEGIN
    IF NEW.actual_return_datetime IS NOT NULL AND OLD.actual_return_datetime IS NULL THEN
        UPDATE Vehicle SET status = 'Available' WHERE vehicle_id = NEW.vehicle_id;
    END IF;
END//

DELIMITER ;

-- =====================================================================
-- PART 6 — SAMPLE DATA
-- Deliberately includes: available / rented / maintenance vehicles,
-- multiple branches & categories, customers with rental history,
-- a currently-active rental, a currently-overdue rental, a returned
-- rental with damage, and both fully-paid and partially-paid invoices.
-- =====================================================================

INSERT INTO Branch (branch_name, city, address, phone) VALUES
('Hitech City Branch',  'Hyderabad', 'Plot 12, HITEC City',   '9000010001'),
('Gachibowli Branch',   'Hyderabad', 'DLF Road, Gachibowli',  '9000010002'),
('Airport Branch',      'Hyderabad', 'RGIA Terminal Rd',      '9000010003'),
('Banjara Hills Branch','Hyderabad', 'Road No. 12, Banjara Hills', '9000010004');

INSERT INTO VehicleCategory (category_name, description) VALUES
('Economy', 'Compact hatchbacks, budget friendly'),
('Sedan',   'Mid-size comfortable sedans'),
('SUV',     'Spacious sport utility vehicles'),
('Luxury',  'Premium high-end vehicles');

INSERT INTO RatePlan (category_id, plan_name, daily_rate, weekly_rate, extra_km_rate, late_fee_per_hour) VALUES
(1, 'Economy Standard',       1200, 7500,  8, 100),
(2, 'Sedan Standard',         2200, 13500, 10, 150),
(3, 'SUV Standard',           3200, 19500, 12, 200),
(4, 'Luxury Standard',        6500, 40000, 20, 400),
(1, 'Economy Weekend Promo',  1000, 6500,  8, 100);

INSERT INTO Vehicle (registration_no, category_id, branch_id, make, model, year, color, current_odometer, status) VALUES
('TS09AB1001', 1, 1, 'Maruti', 'Swift',    2022, 'White',  15000, 'Available'),
('TS09AB1002', 1, 1, 'Tata',   'Tiago',    2021, 'Red',    22000, 'Available'),
('TS09AB1003', 1, 2, 'Hyundai','i10',      2023, 'Blue',    5000, 'Available'),
('TS09AB1004', 2, 1, 'Honda',  'City',     2023, 'Silver',  8000, 'Available'),
('TS09AB1005', 2, 2, 'Hyundai','Verna',    2022, 'Black',  17000, 'Available'),
('TS09AB1006', 2, 3, 'Skoda',  'Slavia',   2023, 'White',   9000, 'Available'),
('TS09AB1007', 3, 2, 'Hyundai','Creta',    2023, 'Black',   6000, 'Available'),
('TS09AB1008', 3, 3, 'Mahindra','XUV700',  2023, 'Grey',   11000, 'Available'),
('TS09AB1009', 3, 4, 'Tata',   'Harrier',  2022, 'Blue',   18000, 'Maintenance'),
('TS09AB1010', 4, 3, 'BMW',    '5 Series', 2024, 'Grey',    2000, 'Available'),
('TS09AB1011', 4, 4, 'Audi',   'A6',       2023, 'Black',   4000, 'Available'),
('TS09AB1012', 1, 4, 'Maruti', 'Baleno',   2022, 'White',  13000, 'Available');

INSERT INTO Customer (full_name, dob, phone, email, license_no, license_expiry, address) VALUES
('Arjun Rao',      '1995-04-12', '9876500001', 'arjun@example.com',    'DLTS1001', '2027-06-30', 'Kondapur, Hyderabad'),
('Priya Menon',    '1990-11-02', '9876500002', 'priya@example.com',    'DLTS1002', '2026-12-15', 'Madhapur, Hyderabad'),
('Suresh Kumar',   '1988-07-20', '9876500003', 'suresh@example.com',   'DLTS1003', '2027-09-01', 'Banjara Hills, Hyderabad'),
('Divya Reddy',    '1996-02-14', '9876500004', 'divya@example.com',    'DLTS1004', '2028-01-20', 'Kukatpally, Hyderabad'),
('Karthik Iyer',   '1992-09-09', '9876500005', 'karthik@example.com',  'DLTS1005', '2027-03-10', 'Miyapur, Hyderabad'),
('Sneha Gupta',    '1994-05-25', '9876500006', 'sneha@example.com',    'DLTS1006', '2026-11-05', 'Begumpet, Hyderabad'),
('Ramesh Babu',    '1985-12-30', '9876500007', 'ramesh@example.com',   'DLTS1007', '2027-08-18', 'Secunderabad'),
('Ananya Singh',   '1998-03-03', '9876500008', 'ananya@example.com',   'DLTS1008', '2028-04-22', 'Jubilee Hills, Hyderabad'),
('Vikram Chowdary','1991-06-17', '9876500009', 'vikram@example.com',   'DLTS1009', '2027-10-11', 'Ameerpet, Hyderabad');

-- Reservations: mix of Converted (became a rental), Completed, Booked (future), Cancelled
INSERT INTO Reservation (customer_id, category_id, pickup_branch_id, return_branch_id, pickup_date, expected_return_date, status) VALUES
(1, 1, 1, 1, '2026-08-01 09:00:00', '2026-08-04 09:00:00', 'Converted'),
(2, 2, 1, 1, '2026-08-05 10:00:00', '2026-08-08 10:00:00', 'Converted'),
(3, 3, 2, 2, '2026-07-20 09:00:00', '2026-07-23 09:00:00', 'Converted'),
(4, 2, 2, 2, '2026-08-10 09:00:00', '2026-08-12 09:00:00', 'Converted'),
(5, 4, 3, 3, '2026-08-15 09:00:00', '2026-08-18 09:00:00', 'Converted'),
(6, 1, 4, 4, '2026-08-20 09:00:00', '2026-08-22 09:00:00', 'Converted'),
(7, 3, 3, 3, '2026-08-25 09:00:00', '2026-08-27 09:00:00', 'Converted'),
(1, 2, 1, 1, '2026-09-01 09:00:00', '2026-09-03 09:00:00', 'Converted'),
(8, 1, 1, 1, '2026-09-25 09:00:00', '2026-09-28 09:00:00', 'Booked'),
(9, 4, 4, 4, '2026-07-10 09:00:00', '2026-07-12 09:00:00', 'Cancelled');

-- Rentals: 9 total, covering Returned (some with damage / partial payment),
-- a currently Active rental, and a currently Overdue rental (dates below
-- use NOW()-relative intervals for the live ones so the demo works on any
-- date it is actually run).
INSERT INTO Rental (reservation_id, vehicle_id, customer_id, rate_plan_id, pickup_branch_id, return_branch_id,
                     pickup_datetime, expected_return_datetime, actual_return_datetime, status) VALUES
(1, 1,  1, 1, 1, 1, '2026-08-01 09:00:00', '2026-08-04 09:00:00', '2026-08-04 10:30:00', 'Returned'),
(2, 4,  2, 2, 1, 1, '2026-08-05 10:00:00', '2026-08-08 10:00:00', '2026-08-08 09:45:00', 'Returned'),
(3, 7,  3, 3, 2, 2, '2026-07-20 09:00:00', '2026-07-23 09:00:00', '2026-07-23 14:00:00', 'Returned'),
(4, 5,  4, 2, 2, 2, '2026-08-10 09:00:00', '2026-08-12 09:00:00', '2026-08-12 09:00:00', 'Returned'),
(5, 10, 5, 4, 3, 3, '2026-08-15 09:00:00', '2026-08-18 09:00:00', '2026-08-18 11:00:00', 'Returned'),
(6, 12, 6, 5, 4, 4, '2026-08-20 09:00:00', '2026-08-22 09:00:00', '2026-08-22 08:30:00', 'Returned'),
(7, 8,  7, 3, 3, 3, '2026-08-25 09:00:00', '2026-08-27 09:00:00', '2026-08-27 09:10:00', 'Returned'),
(8, 2,  1, 1, 1, 1, DATE_SUB(NOW(), INTERVAL 1 DAY), DATE_ADD(NOW(), INTERVAL 2 DAY), NULL, 'Active'),
(NULL, 6, 8, 2, 3, 3, DATE_SUB(NOW(), INTERVAL 5 DAY), DATE_SUB(NOW(), INTERVAL 2 DAY), NULL, 'Overdue');

-- Inspections: pickup + return pair for every Returned rental, pickup-only
-- for the still-Active rental, pickup-only for the Overdue rental.
INSERT INTO Inspection (rental_id, inspection_type, inspection_datetime, odometer_reading, fuel_level_percent, exterior_condition, inspected_by) VALUES
(1, 'Pickup', '2026-08-01 09:00:00', 15000, 100, 'Good', 'Staff01'),
(1, 'Return', '2026-08-04 10:30:00', 15310, 40,  'Minor scratch', 'Staff02'),
(2, 'Pickup', '2026-08-05 10:00:00', 8000,  100, 'Good', 'Staff01'),
(2, 'Return', '2026-08-08 09:45:00', 8290,  55,  'Good', 'Staff03'),
(3, 'Pickup', '2026-07-20 09:00:00', 6000,  90,  'Good', 'Staff02'),
(3, 'Return', '2026-07-23 14:00:00', 6350,  30,  'Good', 'Staff01'),
(4, 'Pickup', '2026-08-10 09:00:00', 17000, 100, 'Good', 'Staff03'),
(4, 'Return', '2026-08-12 09:00:00', 17180, 60,  'Good', 'Staff01'),
(5, 'Pickup', '2026-08-15 09:00:00', 2000,  100, 'Good', 'Staff02'),
(5, 'Return', '2026-08-18 11:00:00', 2410,  35,  'Good', 'Staff02'),
(6, 'Pickup', '2026-08-20 09:00:00', 13000, 100, 'Good', 'Staff03'),
(6, 'Return', '2026-08-22 08:30:00', 13150, 70,  'Good', 'Staff03'),
(7, 'Pickup', '2026-08-25 09:00:00', 11000, 100, 'Good', 'Staff01'),
(7, 'Return', '2026-08-27 09:10:00', 11420, 45,  'Minor scratch', 'Staff02'),
(8, 'Pickup', DATE_SUB(NOW(), INTERVAL 1 DAY), 22000, 100, 'Good', 'Staff01'),
(9, 'Pickup', DATE_SUB(NOW(), INTERVAL 5 DAY), 9000,  100, 'Good', 'Staff02');

INSERT INTO Damage (rental_id, inspection_id, description, repair_cost, charged_amount) VALUES
(1, 2,  'Minor scratch on rear bumper', 800, 800),
(7, 14, 'Small scratch on door', 500, 500),
(3, 6,  'Stain on seat fabric', 300, 300);

-- Invoices for every Returned rental (rentals 1-7)
INSERT INTO Invoice (rental_id, invoice_date, base_charge, extra_km_charge, late_fee, damage_charge, tax_amount, total_amount) VALUES
(1, '2026-08-04 10:30:00', 3600, 0,   375, 800, 858.6,  5633.6),
(2, '2026-08-08 09:45:00', 6600, 0,   0,   0,   1188.0, 7788.0),
(3, '2026-07-23 14:00:00', 9600, 60,  750, 300, 1932.6, 12642.6),
(4, '2026-08-12 09:00:00', 4400, 0,   0,   0,   792.0,  5192.0),
(5, '2026-08-18 11:00:00', 19500,0,   800, 0,   3654.0, 23954.0),
(6, '2026-08-22 08:30:00', 2000, 0,   0,   0,   360.0,  2360.0),
(7, '2026-08-27 09:10:00', 6400, 24,  40,  500, 1246.9, 8210.9);
-- (illustrative: base=daily_rate*days; extra_km_charge for excess km beyond a
--  free allowance; late_fee for hours past expected return; tax @18% GST)

-- Payments: some invoices paid in full in one shot, one paid in two parts
-- (partial payment history), demonstrating the 1:M Invoice-Payment link.
INSERT INTO Payment (invoice_id, payment_date, amount, payment_mode, transaction_ref) VALUES
(1, '2026-08-04 10:40:00', 5633.6, 'UPI',  'TXN20260804001'),
(2, '2026-08-08 09:50:00', 4000.0, 'Card', 'TXN20260808001'),
(2, '2026-08-09 12:00:00', 3788.0, 'UPI',  'TXN20260809001'),  -- partial payment 2nd installment
(3, '2026-07-23 14:10:00', 12642.6,'Cash', 'TXN20260723001'),
(4, '2026-08-12 09:05:00', 5192.0, 'UPI',  'TXN20260812001'),
(5, '2026-08-18 11:15:00', 23954.0,'Card', 'TXN20260818001'),
(6, '2026-08-22 08:40:00', 2360.0, 'Cash', 'TXN20260822001'),
(7, '2026-08-27 09:20:00', 5000.0, 'UPI',  'TXN20260827001');  -- invoice 7 still has 3210.90 outstanding

-- =====================================================================
-- PART 7 — REQUIRED SQL QUERIES
-- =====================================================================

-- (A) JOINS -----------------------------------------------------------

-- A1. Customer rental history (INNER JOIN across 4 tables)
SELECT c.full_name, v.registration_no, r.pickup_datetime, r.actual_return_datetime, i.total_amount
FROM Rental r
JOIN Customer c ON r.customer_id = c.customer_id
JOIN Vehicle v  ON r.vehicle_id  = v.vehicle_id
LEFT JOIN Invoice i ON i.rental_id = r.rental_id
WHERE c.customer_id = 1
ORDER BY r.pickup_datetime;

-- A2. Rental + vehicle + customer details (all active/overdue rentals)
SELECT r.rental_id, c.full_name, c.phone, v.registration_no, v.make, v.model, r.status
FROM Rental r
JOIN Customer c ON r.customer_id = c.customer_id
JOIN Vehicle v  ON r.vehicle_id  = v.vehicle_id
WHERE r.status IN ('Active','Overdue');

-- A3. Invoice + payment details (LEFT JOIN shows invoices even with no payment yet)
SELECT inv.invoice_id, inv.total_amount, p.payment_date, p.amount, p.payment_mode
FROM Invoice inv
LEFT JOIN Payment p ON p.invoice_id = inv.invoice_id
ORDER BY inv.invoice_id;

-- A4. Damage + rental + vehicle details
SELECT v.registration_no, c.full_name, d.description, d.repair_cost, d.charged_amount
FROM Damage d
JOIN Rental r  ON d.rental_id  = r.rental_id
JOIN Vehicle v ON r.vehicle_id = v.vehicle_id
JOIN Customer c ON r.customer_id = c.customer_id;

-- (B) SUBQUERIES --------------------------------------------------------

-- B1. Customers who rented more than the average number of times
SELECT c.full_name, COUNT(r.rental_id) AS rental_count
FROM Customer c
JOIN Rental r ON c.customer_id = r.customer_id
GROUP BY c.customer_id, c.full_name
HAVING COUNT(r.rental_id) > (
    SELECT AVG(cnt) FROM (
        SELECT COUNT(*) AS cnt FROM Rental GROUP BY customer_id
    ) sub
);

-- B2. Vehicles whose rental count is above the fleet average
SELECT v.registration_no, COUNT(r.rental_id) AS times_rented
FROM Vehicle v
JOIN Rental r ON v.vehicle_id = r.vehicle_id
GROUP BY v.vehicle_id, v.registration_no
HAVING COUNT(r.rental_id) > (
    SELECT AVG(cnt) FROM (
        SELECT COUNT(*) AS cnt FROM Rental GROUP BY vehicle_id
    ) sub
);

-- B3. Branches generating revenue above the average branch revenue
SELECT b.branch_name, SUM(i.total_amount) AS revenue
FROM Branch b
JOIN Rental r  ON b.branch_id = r.pickup_branch_id
JOIN Invoice i ON i.rental_id = r.rental_id
GROUP BY b.branch_id, b.branch_name
HAVING SUM(i.total_amount) > (
    SELECT AVG(branch_total) FROM (
        SELECT SUM(i2.total_amount) AS branch_total
        FROM Rental r2 JOIN Invoice i2 ON i2.rental_id = r2.rental_id
        GROUP BY r2.pickup_branch_id
    ) sub2
);

-- (C) AGGREGATION --------------------------------------------------------

-- C1. Number of rentals per branch
SELECT b.branch_name, COUNT(r.rental_id) AS total_rentals
FROM Branch b LEFT JOIN Rental r ON b.branch_id = r.pickup_branch_id
GROUP BY b.branch_id, b.branch_name;

-- C2. Revenue per branch
SELECT b.branch_name, SUM(i.total_amount) AS total_revenue
FROM Branch b
JOIN Rental r  ON b.branch_id = r.pickup_branch_id
JOIN Invoice i ON i.rental_id = r.rental_id
GROUP BY b.branch_id, b.branch_name
ORDER BY total_revenue DESC;

-- C3. Vehicle utilization (rentals + total days rented per vehicle)
SELECT v.registration_no,
       COUNT(r.rental_id) AS total_rentals,
       SUM(DATEDIFF(COALESCE(r.actual_return_datetime, NOW()), r.pickup_datetime)) AS total_days_rented
FROM Vehicle v
LEFT JOIN Rental r ON v.vehicle_id = r.vehicle_id
GROUP BY v.vehicle_id, v.registration_no
ORDER BY total_days_rented DESC;

-- C4. Total damage cost per vehicle
SELECT v.registration_no, COUNT(d.damage_id) AS damage_count,
       SUM(d.repair_cost) AS total_repair_cost, SUM(d.charged_amount) AS total_charged
FROM Vehicle v
JOIN Rental r  ON v.vehicle_id = r.vehicle_id
JOIN Damage d  ON d.rental_id  = r.rental_id
GROUP BY v.vehicle_id, v.registration_no;

-- C5. Rental count per customer (min/max/avg overall)
SELECT MIN(cnt) AS min_rentals, MAX(cnt) AS max_rentals, AVG(cnt) AS avg_rentals
FROM (SELECT COUNT(*) AS cnt FROM Rental GROUP BY customer_id) t;

-- (D) VIEWS --------------------------------------------------------------

CREATE OR REPLACE VIEW vw_fleet_availability AS
SELECT v.vehicle_id, v.registration_no, vc.category_name, b.branch_name, v.status
FROM Vehicle v
JOIN VehicleCategory vc ON v.category_id = vc.category_id
JOIN Branch b            ON v.branch_id  = b.branch_id
WHERE v.status = 'Available';

CREATE OR REPLACE VIEW vw_overdue_rentals AS
SELECT r.rental_id, c.full_name, c.phone, v.registration_no, r.expected_return_datetime,
       TIMESTAMPDIFF(HOUR, r.expected_return_datetime, NOW()) AS hours_overdue
FROM Rental r
JOIN Customer c ON r.customer_id = c.customer_id
JOIN Vehicle v  ON r.vehicle_id  = v.vehicle_id
WHERE r.actual_return_datetime IS NULL AND r.expected_return_datetime < NOW();

CREATE OR REPLACE VIEW vw_customer_rental_history AS
SELECT c.customer_id, c.full_name, v.registration_no, r.pickup_datetime,
       r.actual_return_datetime, i.total_amount
FROM Rental r
JOIN Customer c ON r.customer_id = c.customer_id
JOIN Vehicle v  ON r.vehicle_id  = v.vehicle_id
LEFT JOIN Invoice i ON i.rental_id = r.rental_id;

CREATE OR REPLACE VIEW vw_branch_revenue AS
SELECT b.branch_id, b.branch_name, SUM(i.total_amount) AS total_revenue, COUNT(i.invoice_id) AS invoice_count
FROM Invoice i
JOIN Rental r ON i.rental_id = r.rental_id
JOIN Branch b ON r.pickup_branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name;

CREATE OR REPLACE VIEW vw_vehicle_utilization AS
SELECT v.vehicle_id, v.registration_no,
       COUNT(r.rental_id) AS total_rentals,
       SUM(DATEDIFF(COALESCE(r.actual_return_datetime, NOW()), r.pickup_datetime)) AS total_days_rented
FROM Vehicle v
LEFT JOIN Rental r ON v.vehicle_id = r.vehicle_id
GROUP BY v.vehicle_id, v.registration_no;

CREATE OR REPLACE VIEW vw_damage_report AS
SELECT d.damage_id, v.registration_no, c.full_name, d.description, d.repair_cost, d.charged_amount
FROM Damage d
JOIN Rental r   ON d.rental_id  = r.rental_id
JOIN Vehicle v  ON r.vehicle_id = v.vehicle_id
JOIN Customer c ON r.customer_id = c.customer_id;

-- =====================================================================
-- PART 8 — THE SIX REQUIRED REPORTS (thin wrappers over the views above)
-- =====================================================================
-- 1. Fleet Availability
SELECT * FROM vw_fleet_availability;
-- 2. Overdue Rentals
SELECT * FROM vw_overdue_rentals;
-- 3. Vehicle Utilization
SELECT * FROM vw_vehicle_utilization ORDER BY total_days_rented DESC;
-- 4. Damage Report
SELECT * FROM vw_damage_report;
-- 5. Branch Revenue
SELECT * FROM vw_branch_revenue ORDER BY total_revenue DESC;
-- 6. Customer History
SELECT * FROM vw_customer_rental_history WHERE customer_id = 1 ORDER BY pickup_datetime;

-- =====================================================================
-- PART 9 — TRANSACTIONS
-- =====================================================================

-- 9A. SUCCESSFUL TRANSACTION — issuing a rental atomically.
-- Three statements (Rental insert, pickup Inspection insert, and the
-- AFTER INSERT trigger's Vehicle status update) must all succeed together;
-- if anything fails partway, none of it should stick.
START TRANSACTION;

INSERT INTO Rental (reservation_id, vehicle_id, customer_id, rate_plan_id, pickup_branch_id, return_branch_id,
                     pickup_datetime, expected_return_datetime, status)
VALUES (NULL, 3, 9, 1, 2, 2, NOW(), DATE_ADD(NOW(), INTERVAL 3 DAY), 'Active');

SET @new_rental_id = LAST_INSERT_ID();

INSERT INTO Inspection (rental_id, inspection_type, odometer_reading, fuel_level_percent, inspected_by)
VALUES (@new_rental_id, 'Pickup', 5000, 100, 'Staff02');

COMMIT;

-- 9B. ROLLBACK EXAMPLE — an operation sequence that must be undone.
-- Important nuance for viva: in MySQL/InnoDB, a single statement failing
-- on a CHECK/trigger violation does NOT automatically roll back the whole
-- transaction the way some other databases do - the failed statement is
-- simply rejected, and everything already run in that transaction is still
-- sitting there uncommitted. It is the application's/DBA's job to notice
-- the error and issue ROLLBACK explicitly. That's demonstrated below.
START TRANSACTION;

    -- Step 1: succeeds
    INSERT INTO Payment (invoice_id, amount, payment_mode, transaction_ref)
    VALUES (7, 1000.00, 'Cash', 'TXN_DEMO_STEP1');

    -- Step 2: this INSERT is intentionally invalid (negative amount violates
    -- the CHECK constraint amount > 0) and will be rejected by MySQL.
    -- INSERT INTO Payment (invoice_id, amount, payment_mode, transaction_ref)
    -- VALUES (7, -500.00, 'Cash', 'TXN_DEMO_STEP2_BAD');

    -- Because step 2 failed the CHECK, we did not get the outcome we
    -- wanted (both payments recorded together) - so we roll back step 1
    -- as well, keeping the invoice's payment history consistent.
ROLLBACK;
-- Verify: SELECT * FROM Payment WHERE transaction_ref = 'TXN_DEMO_STEP1'; --> no row, rollback worked

-- =====================================================================
-- PART 11 — LIVE DEMO: CONSTRAINT / TRIGGER VALIDATION
-- Run these ONE AT A TIME during the demo - each is expected to be
-- REJECTED by the database, proving the rule is enforced at the DB layer
-- and not just in application code.
-- =====================================================================

-- (i) CHECK constraint - non-negative charge violated
-- INSERT INTO Payment (invoice_id, amount, payment_mode) VALUES (1, -100, 'Cash');
-- Expected: Error - CHECK constraint 'payment_chk_1' is violated.

-- (ii) CHECK constraint - return before pickup
-- INSERT INTO Rental (vehicle_id, customer_id, rate_plan_id, pickup_branch_id, return_branch_id,
--                      pickup_datetime, expected_return_datetime, actual_return_datetime)
-- VALUES (1, 1, 1, 1, 1, '2026-09-10 09:00:00', '2026-09-12 09:00:00', '2026-09-09 09:00:00');
-- Expected: Error - CHECK constraint on actual_return_datetime > pickup_datetime is violated.

-- (iii) Trigger - overlapping rental for the same vehicle
-- INSERT INTO Rental (vehicle_id, customer_id, rate_plan_id, pickup_branch_id, return_branch_id,
--                      pickup_datetime, expected_return_datetime, status)
-- VALUES (2, 3, 1, 1, 1, NOW(), DATE_ADD(NOW(), INTERVAL 1 DAY), 'Active');
-- Expected: Error 45000 - 'Vehicle already has an overlapping active rental' (vehicle_id 2 is rental 8's vehicle).

-- (iv) Trigger - expired licence at pickup
-- Uses vehicle_id 11, which has no Active/Overdue rental at this point in
-- the script, so the overlap trigger passes cleanly and it is genuinely
-- the licence trigger that rejects the insert (not a vehicle clash).
-- First add a customer with an expired licence to demonstrate this safely:
-- INSERT INTO Customer (full_name, dob, phone, email, license_no, license_expiry, address)
-- VALUES ('Test Expired', '1990-01-01', '9999999999', 'test@example.com', 'DLTS9999', '2020-01-01', 'Test Address');
-- INSERT INTO Rental (vehicle_id, customer_id, rate_plan_id, pickup_branch_id, return_branch_id,
--                      pickup_datetime, expected_return_datetime, status)
-- VALUES (11, LAST_INSERT_ID(), 4, 4, 4, NOW(), DATE_ADD(NOW(), INTERVAL 1 DAY), 'Active');
-- Expected: Error 45000 - 'Customer driving license has expired'.

-- =====================================================================
-- END OF SCRIPT
-- =====================================================================
