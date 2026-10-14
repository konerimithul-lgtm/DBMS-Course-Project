-- =====================================================================
-- CAR RENTAL RESERVATION AND VEHICLE RETURN MANAGEMENT SYSTEM
-- DBMS PBL - Project 19
-- Dialect: MySQL 8.x  (swap AUTO_INCREMENT / DELIMITER syntax if using
--          PostgreSQL: SERIAL instead of AUTO_INCREMENT, and use
--          plpgsql CREATE FUNCTION + CREATE TRIGGER instead of the
--          MySQL trigger blocks below)
-- =====================================================================

DROP DATABASE IF EXISTS car_rental_db;
CREATE DATABASE car_rental_db;
USE car_rental_db;

-- =====================================================================
-- 1. TABLES
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
    FOREIGN KEY (category_id) REFERENCES VehicleCategory(category_id),
    FOREIGN KEY (branch_id)   REFERENCES Branch(branch_id)
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
);

CREATE TABLE Reservation (
    reservation_id      INT AUTO_INCREMENT PRIMARY KEY,
    customer_id          INT NOT NULL,
    category_id          INT NOT NULL,
    pickup_branch_id     INT NOT NULL,
    return_branch_id     INT NOT NULL,
    reservation_date     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    pickup_date          DATETIME NOT NULL,
    expected_return_date DATETIME NOT NULL,
    status                VARCHAR(15) NOT NULL DEFAULT 'Booked'
                            CHECK (status IN ('Booked','Cancelled','Completed','Converted')),
    FOREIGN KEY (customer_id)      REFERENCES Customer(customer_id),
    FOREIGN KEY (category_id)      REFERENCES VehicleCategory(category_id),
    FOREIGN KEY (pickup_branch_id) REFERENCES Branch(branch_id),
    FOREIGN KEY (return_branch_id) REFERENCES Branch(branch_id),
    CHECK (expected_return_date > pickup_date)
);

CREATE TABLE Rental (
    rental_id               INT AUTO_INCREMENT PRIMARY KEY,
    reservation_id           INT NULL,
    vehicle_id                INT NOT NULL,
    customer_id                INT NOT NULL,
    rate_plan_id                INT NOT NULL,
    pickup_branch_id             INT NOT NULL,
    return_branch_id              INT NOT NULL,
    pickup_datetime                 DATETIME NOT NULL,
    expected_return_datetime          DATETIME NOT NULL,
    actual_return_datetime               DATETIME NULL,
    status                                  VARCHAR(15) NOT NULL DEFAULT 'Active'
                                              CHECK (status IN ('Active','Returned','Overdue')),
    FOREIGN KEY (reservation_id)     REFERENCES Reservation(reservation_id),
    FOREIGN KEY (vehicle_id)         REFERENCES Vehicle(vehicle_id),
    FOREIGN KEY (customer_id)        REFERENCES Customer(customer_id),
    FOREIGN KEY (rate_plan_id)       REFERENCES RatePlan(rate_plan_id),
    FOREIGN KEY (pickup_branch_id)   REFERENCES Branch(branch_id),
    FOREIGN KEY (return_branch_id)   REFERENCES Branch(branch_id),
    -- Business rule: return after pickup
    CHECK (actual_return_datetime IS NULL OR actual_return_datetime > pickup_datetime),
    CHECK (expected_return_datetime > pickup_datetime)
);

CREATE TABLE Inspection (
    inspection_id       INT AUTO_INCREMENT PRIMARY KEY,
    rental_id             INT NOT NULL,
    inspection_type        VARCHAR(10) NOT NULL CHECK (inspection_type IN ('Pickup','Return')),
    inspection_datetime      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    odometer_reading           INT NOT NULL CHECK (odometer_reading >= 0),
    fuel_level_percent           INT NOT NULL CHECK (fuel_level_percent BETWEEN 0 AND 100),
    exterior_condition             VARCHAR(20) DEFAULT 'Good',
    notes                             VARCHAR(200),
    inspected_by                        VARCHAR(60),
    FOREIGN KEY (rental_id) REFERENCES Rental(rental_id)
);

CREATE TABLE Damage (
    damage_id      INT AUTO_INCREMENT PRIMARY KEY,
    rental_id        INT NOT NULL,
    inspection_id      INT NULL,
    description           VARCHAR(200) NOT NULL,
    repair_cost              DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (repair_cost >= 0),
    charged_amount              DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (charged_amount >= 0),
    FOREIGN KEY (rental_id)     REFERENCES Rental(rental_id),
    FOREIGN KEY (inspection_id) REFERENCES Inspection(inspection_id)
);

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
    FOREIGN KEY (rental_id) REFERENCES Rental(rental_id)
);

CREATE TABLE Payment (
    payment_id     INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id       INT NOT NULL,
    payment_date        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    amount                  DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    payment_mode               VARCHAR(15) NOT NULL CHECK (payment_mode IN ('Cash','Card','UPI','NetBanking')),
    transaction_ref                VARCHAR(40),
    FOREIGN KEY (invoice_id) REFERENCES Invoice(invoice_id)
);

-- Helpful indexes on frequently-searched columns
CREATE INDEX idx_vehicle_status      ON Vehicle(status);
CREATE INDEX idx_customer_license    ON Customer(license_no);
CREATE INDEX idx_rental_vehicle      ON Rental(vehicle_id);
CREATE INDEX idx_rental_status       ON Rental(status);
CREATE INDEX idx_invoice_rental      ON Invoice(rental_id);

-- =====================================================================
-- 2. TRIGGERS  (cross-row business rules a plain CHECK cannot express)
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
-- pickup odometer reading for the same rental
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

-- Keep Vehicle.status and current_odometer in sync automatically
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
-- 3. SAMPLE DATA
-- =====================================================================

INSERT INTO Branch (branch_name, city, address, phone) VALUES
('Hitech City Branch', 'Hyderabad', 'Plot 12, HITEC City', '9000010001'),
('Gachibowli Branch',  'Hyderabad', 'DLF Road, Gachibowli', '9000010002'),
('Airport Branch',     'Hyderabad', 'RGIA Terminal Rd',     '9000010003');

INSERT INTO VehicleCategory (category_name, description) VALUES
('Economy', 'Compact hatchbacks, budget friendly'),
('Sedan',   'Mid-size comfortable sedans'),
('SUV',     'Spacious sport utility vehicles'),
('Luxury',  'Premium high-end vehicles');

INSERT INTO Vehicle (registration_no, category_id, branch_id, make, model, year, color, current_odometer, status) VALUES
('TS09AB1234', 1, 1, 'Maruti', 'Swift',     2022, 'White', 15000, 'Available'),
('TS09AB1235', 2, 1, 'Honda',  'City',      2023, 'Silver', 8000, 'Available'),
('TS09AB1236', 3, 2, 'Hyundai','Creta',     2023, 'Black',  6000, 'Available'),
('TS09AB1237', 4, 3, 'BMW',    '5 Series',  2024, 'Grey',   2000, 'Available'),
('TS09AB1238', 1, 2, 'Tata',   'Tiago',     2021, 'Red',   22000, 'Maintenance');

INSERT INTO Customer (full_name, dob, phone, email, license_no, license_expiry, address) VALUES
('Arjun Rao',    '1995-04-12', '9876500001', 'arjun@example.com',    'DLTS1001', '2027-06-30', 'Kondapur, Hyderabad'),
('Priya Menon',  '1990-11-02', '9876500002', 'priya@example.com',    'DLTS1002', '2026-01-15', 'Madhapur, Hyderabad'),
('Suresh Kumar', '1988-07-20', '9876500003', 'suresh@example.com',   'DLTS1003', '2025-09-01', 'Banjara Hills, Hyderabad');

INSERT INTO RatePlan (category_id, plan_name, daily_rate, weekly_rate, extra_km_rate, late_fee_per_hour) VALUES
(1, 'Economy Standard', 1200, 7500, 8, 100),
(2, 'Sedan Standard',   2200, 13500, 10, 150),
(3, 'SUV Standard',     3200, 19500, 12, 200),
(4, 'Luxury Standard',  6500, 40000, 20, 400);

INSERT INTO Reservation (customer_id, category_id, pickup_branch_id, return_branch_id, pickup_date, expected_return_date, status) VALUES
(1, 1, 1, 1, '2026-08-10 09:00:00', '2026-08-13 09:00:00', 'Converted'),
(2, 2, 1, 1, '2026-08-15 10:00:00', '2026-08-18 10:00:00', 'Booked');

-- A completed rental (Arjun Rao, converted from reservation 1)
INSERT INTO Rental (reservation_id, vehicle_id, customer_id, rate_plan_id, pickup_branch_id, return_branch_id,
                     pickup_datetime, expected_return_datetime, actual_return_datetime, status) VALUES
(1, 1, 1, 1, 1, 1, '2026-08-10 09:00:00', '2026-08-13 09:00:00', '2026-08-13 11:30:00', 'Returned');

INSERT INTO Inspection (rental_id, inspection_type, inspection_datetime, odometer_reading, fuel_level_percent, exterior_condition, inspected_by) VALUES
(1, 'Pickup', '2026-08-10 09:00:00', 15000, 100, 'Good', 'Staff01'),
(1, 'Return', '2026-08-13 11:30:00', 15310, 40,  'Minor scratch', 'Staff02');

INSERT INTO Damage (rental_id, inspection_id, description, repair_cost, charged_amount) VALUES
(1, 2, 'Minor scratch on rear bumper', 800, 800);

INSERT INTO Invoice (rental_id, base_charge, extra_km_charge, late_fee, damage_charge, tax_amount, total_amount) VALUES
(1, 3600, 0, 375, 800, 468.30, 5243.30);
-- 3 days @1200=3600; 2.5 hrs late @100/hr ~ rounded to 375; damage 800; 18% GST on (3600+375+800)=4775*0.18=859.5 -- (illustrative, adjust as you like)

INSERT INTO Payment (invoice_id, amount, payment_mode, transaction_ref) VALUES
(1, 5243.30, 'UPI', 'TXN20260813001');

-- Walk-in rental currently active (no reservation), for overdue/availability demo
INSERT INTO Rental (reservation_id, vehicle_id, customer_id, rate_plan_id, pickup_branch_id, return_branch_id,
                     pickup_datetime, expected_return_datetime, actual_return_datetime, status) VALUES
(NULL, 3, 3, 3, 2, 2, '2026-08-18 09:00:00', '2026-08-20 09:00:00', NULL, 'Active');

INSERT INTO Inspection (rental_id, inspection_type, odometer_reading, fuel_level_percent, inspected_by) VALUES
(2, 'Pickup', 6000, 90, 'Staff03');

-- =====================================================================
-- 4. REQUIRED SQL QUERIES  (joins, aggregates, subquery, views)
-- Reports named in the brief: fleet availability, overdue rentals,
-- utilization, damages, branch revenue, customer history
-- =====================================================================

-- (a) JOIN + WHERE — Fleet availability by branch
SELECT v.registration_no, v.make, v.model, vc.category_name, b.branch_name
FROM Vehicle v
JOIN VehicleCategory vc ON v.category_id = vc.category_id
JOIN Branch b            ON v.branch_id  = b.branch_id
WHERE v.status = 'Available';

-- (b) JOIN + date comparison — Overdue rentals (not returned, past expected date)
SELECT r.rental_id, c.full_name, v.registration_no, r.expected_return_datetime
FROM Rental r
JOIN Customer c ON r.customer_id = c.customer_id
JOIN Vehicle v  ON r.vehicle_id  = v.vehicle_id
WHERE r.actual_return_datetime IS NULL
  AND r.expected_return_datetime < NOW();

-- (c) AGGREGATE + GROUP BY — Vehicle utilization (days rented per vehicle)
SELECT v.registration_no,
       COUNT(r.rental_id) AS total_rentals,
       SUM(DATEDIFF(COALESCE(r.actual_return_datetime, NOW()), r.pickup_datetime)) AS total_days_rented
FROM Vehicle v
LEFT JOIN Rental r ON v.vehicle_id = r.vehicle_id
GROUP BY v.vehicle_id, v.registration_no
ORDER BY total_days_rented DESC;

-- (d) JOIN + AGGREGATE — Damage report per vehicle
SELECT v.registration_no, d.description, d.repair_cost, d.charged_amount
FROM Damage d
JOIN Rental r  ON d.rental_id = r.rental_id
JOIN Vehicle v ON r.vehicle_id = v.vehicle_id;

-- (e) JOIN + GROUP BY on money — Branch revenue
SELECT b.branch_name, SUM(i.total_amount) AS total_revenue
FROM Invoice i
JOIN Rental r  ON i.rental_id = r.rental_id
JOIN Branch b  ON r.pickup_branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name
ORDER BY total_revenue DESC;

-- (f) JOIN across many tables — Customer rental history
SELECT c.full_name, v.registration_no, r.pickup_datetime, r.actual_return_datetime,
       i.total_amount
FROM Rental r
JOIN Customer c ON r.customer_id = c.customer_id
JOIN Vehicle v  ON r.vehicle_id  = v.vehicle_id
LEFT JOIN Invoice i ON i.rental_id = r.rental_id
WHERE c.customer_id = 1
ORDER BY r.pickup_datetime;

-- (g) NESTED SUBQUERY — customers who have spent above the average total invoice amount
SELECT c.full_name, SUM(i.total_amount) AS total_spent
FROM Customer c
JOIN Rental r  ON c.customer_id = r.customer_id
JOIN Invoice i ON r.rental_id   = i.rental_id
GROUP BY c.customer_id, c.full_name
HAVING SUM(i.total_amount) > (
    SELECT AVG(total_amount) FROM Invoice
);

-- (h) VIEW — Fleet availability (used by the app's "Availability Search" module)
CREATE OR REPLACE VIEW vw_fleet_availability AS
SELECT v.vehicle_id, v.registration_no, vc.category_name, b.branch_name, v.status
FROM Vehicle v
JOIN VehicleCategory vc ON v.category_id = vc.category_id
JOIN Branch b            ON v.branch_id  = b.branch_id
WHERE v.status = 'Available';

-- (i) VIEW — Overdue rentals
CREATE OR REPLACE VIEW vw_overdue_rentals AS
SELECT r.rental_id, c.full_name, c.phone, v.registration_no, r.expected_return_datetime
FROM Rental r
JOIN Customer c ON r.customer_id = c.customer_id
JOIN Vehicle v  ON r.vehicle_id  = v.vehicle_id
WHERE r.actual_return_datetime IS NULL AND r.expected_return_datetime < NOW();

-- (j) VIEW — Branch revenue summary
CREATE OR REPLACE VIEW vw_branch_revenue AS
SELECT b.branch_name, SUM(i.total_amount) AS total_revenue, COUNT(i.invoice_id) AS invoice_count
FROM Invoice i
JOIN Rental r ON i.rental_id = r.rental_id
JOIN Branch b ON r.pickup_branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name;

-- Quick sanity checks after loading:
-- SELECT * FROM vw_fleet_availability;
-- SELECT * FROM vw_overdue_rentals;
-- SELECT * FROM vw_branch_revenue;
