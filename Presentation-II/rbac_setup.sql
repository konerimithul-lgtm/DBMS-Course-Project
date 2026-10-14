-- =====================================================================
-- CAR RENTAL RESERVATION AND VEHICLE RETURN MANAGEMENT SYSTEM
-- REVIEW 2 - PART A: ROLE-BASED ACCESS CONTROL (RBAC)
-- Dialect: MySQL 8.x / MariaDB 10.5+ (both support CREATE ROLE)
-- Run this AFTER car_rental_review2.sql (needs the database + tables to exist)
-- =====================================================================

USE car_rental_db;

-- ---------------------------------------------------------------------
-- IMPORTANT DESIGN NOTE (read before the GRANTs below)
-- MySQL/MariaDB privileges are table- and column-level, not row-level.
-- A single 'customer_role' database account is shared by the APPLICATION
-- layer for every logged-in customer (via connection pooling) - the DB
-- engine has no built-in concept of "only rows where customer_id = me".
-- So RBAC here does two different jobs at two different layers:
--   1. DATABASE layer (this file): which TABLES/COLUMNS a role can touch
--      at all, and with which operations (SELECT/INSERT/UPDATE/DELETE).
--      e.g. a customer's connection can never INSERT into Vehicle, full stop.
--   2. APPLICATION layer (not SQL): which ROWS within an allowed table a
--      given logged-in customer may see/touch - e.g. every Reservation
--      query the app runs for a customer is scoped with
--      "WHERE customer_id = :logged_in_customer_id".
-- This split is normal and expected - it is NOT a gap in the design.
-- ---------------------------------------------------------------------

-- =====================================================================
-- ROLE DEFINITIONS
-- =====================================================================

DROP ROLE IF EXISTS 'customer_role', 'branch_staff_role', 'branch_manager_role';
CREATE ROLE 'customer_role';
CREATE ROLE 'branch_staff_role';
CREATE ROLE 'branch_manager_role';

-- No role in this system is ever granted DELETE. The system never
-- physically deletes operational history - a vehicle is marked
-- status='Retired' rather than removed, a cancelled reservation stays
-- as status='Cancelled', etc. This is consistent with the ON DELETE
-- RESTRICT chosen for Invoice/Payment in the schema itself.

-- ---------------------------------------------------------------------
-- 1. CUSTOMER_ROLE
-- ---------------------------------------------------------------------
GRANT SELECT ON car_rental_db.VehicleCategory      TO 'customer_role';  -- view categories
GRANT SELECT ON car_rental_db.Vehicle              TO 'customer_role';  -- view available vehicles
GRANT SELECT ON car_rental_db.RatePlan             TO 'customer_role';  -- see pricing when booking
GRANT SELECT ON car_rental_db.Branch               TO 'customer_role';  -- pick a branch
GRANT SELECT, INSERT ON car_rental_db.Reservation  TO 'customer_role';  -- make + view own reservations
GRANT SELECT ON car_rental_db.Rental               TO 'customer_role';  -- view own rental history (read-only)
GRANT SELECT ON car_rental_db.Inspection           TO 'customer_role';  -- view condition record of own rentals
GRANT SELECT ON car_rental_db.Damage               TO 'customer_role';  -- view damage charged to them
GRANT SELECT ON car_rental_db.Invoice              TO 'customer_role';  -- view own invoices
GRANT SELECT ON car_rental_db.Payment              TO 'customer_role';  -- view own payment history
GRANT SELECT, UPDATE (full_name, phone, email, address) ON car_rental_db.Customer TO 'customer_role';
    -- can update their own contact details, but NOT license_no/license_expiry
    -- (licence data should only change via a verified staff-side process)
GRANT SELECT ON car_rental_db.vw_fleet_availability TO 'customer_role';
    -- the customer-facing "search availability" screen queries this view
    -- directly; MariaDB requires a grant on the VIEW itself, separate from
    -- the grants on the underlying tables it reads (confirmed by testing
    -- below - a role with table-level SELECT on Vehicle still gets
    -- "SELECT command denied ... for table vw_fleet_availability" until
    -- the view is granted explicitly).
-- Explicitly NOT granted: INSERT/UPDATE/DELETE on Vehicle, RatePlan, Branch,
-- Damage, Inspection, Invoice, Payment; any access to other Customer rows
-- beyond their own (enforced at application layer, see note above).

-- ---------------------------------------------------------------------
-- 2. BRANCH_STAFF_ROLE
-- ---------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON car_rental_db.Customer     TO 'branch_staff_role'; -- manage customer records
GRANT SELECT ON car_rental_db.VehicleCategory              TO 'branch_staff_role';
GRANT SELECT ON car_rental_db.RatePlan                     TO 'branch_staff_role';
GRANT SELECT ON car_rental_db.Branch                       TO 'branch_staff_role';
GRANT SELECT ON car_rental_db.Vehicle                      TO 'branch_staff_role'; -- search availability
GRANT UPDATE (status, current_odometer) ON car_rental_db.Vehicle TO 'branch_staff_role';
    -- column-level grant: staff can flip status / log odometer, but cannot
    -- rewrite make/model/category/branch - that's a manager-level edit
GRANT SELECT, INSERT, UPDATE ON car_rental_db.Reservation  TO 'branch_staff_role'; -- create/update reservations
GRANT SELECT, INSERT, UPDATE ON car_rental_db.Rental       TO 'branch_staff_role'; -- issue vehicles, log return
GRANT SELECT, INSERT ON car_rental_db.Inspection           TO 'branch_staff_role'; -- pickup & return inspections
GRANT SELECT, INSERT ON car_rental_db.Damage               TO 'branch_staff_role'; -- record damage
GRANT SELECT, INSERT, UPDATE ON car_rental_db.Invoice      TO 'branch_staff_role'; -- generate/update invoices
GRANT SELECT, INSERT ON car_rental_db.Payment              TO 'branch_staff_role'; -- record payments
-- Explicitly NOT granted: INSERT/UPDATE on VehicleCategory, RatePlan, Branch
-- (those are branch-manager-level configuration, not day-to-day operation).

-- ---------------------------------------------------------------------
-- 3. BRANCH_MANAGER_ROLE
-- Inherits every staff privilege, then adds management-level access.
-- ---------------------------------------------------------------------
GRANT 'branch_staff_role' TO 'branch_manager_role';

GRANT SELECT, INSERT, UPDATE ON car_rental_db.Vehicle         TO 'branch_manager_role'; -- full vehicle record management
GRANT SELECT, INSERT, UPDATE ON car_rental_db.VehicleCategory TO 'branch_manager_role';
GRANT SELECT, INSERT, UPDATE ON car_rental_db.RatePlan        TO 'branch_manager_role';
GRANT SELECT ON car_rental_db.Damage                          TO 'branch_manager_role'; -- review (staff already has INSERT)
GRANT SELECT ON car_rental_db.Inspection                      TO 'branch_manager_role'; -- review
GRANT SELECT ON car_rental_db.Invoice                         TO 'branch_manager_role';
GRANT SELECT ON car_rental_db.Payment                         TO 'branch_manager_role';
-- Reporting views (created in car_rental_review2.sql)
GRANT SELECT ON car_rental_db.vw_fleet_availability        TO 'branch_manager_role';
GRANT SELECT ON car_rental_db.vw_overdue_rentals           TO 'branch_manager_role';
GRANT SELECT ON car_rental_db.vw_customer_rental_history   TO 'branch_manager_role';
GRANT SELECT ON car_rental_db.vw_branch_revenue            TO 'branch_manager_role';
GRANT SELECT ON car_rental_db.vw_vehicle_utilization       TO 'branch_manager_role';
GRANT SELECT ON car_rental_db.vw_damage_report             TO 'branch_manager_role';
-- Branch table itself: a manager may need to update their own branch's
-- contact info, staff role only needed SELECT.
GRANT UPDATE (address, phone) ON car_rental_db.Branch TO 'branch_manager_role';

FLUSH PRIVILEGES;

-- =====================================================================
-- SAMPLE DB USERS - ONE PER ROLE, FOR DEMO/TESTING PURPOSES
-- In production the application would use one pooled account per role
-- (not one per human), with the app enforcing row-level scoping.
-- =====================================================================
DROP USER IF EXISTS 'demo_customer'@'localhost', 'demo_staff'@'localhost', 'demo_manager'@'localhost';
CREATE USER 'demo_customer'@'localhost' IDENTIFIED BY 'CustPass123!';
CREATE USER 'demo_staff'@'localhost'    IDENTIFIED BY 'StaffPass123!';
CREATE USER 'demo_manager'@'localhost'  IDENTIFIED BY 'MgrPass123!';

GRANT 'customer_role'       TO 'demo_customer'@'localhost';
GRANT 'branch_staff_role'   TO 'demo_staff'@'localhost';
GRANT 'branch_manager_role' TO 'demo_manager'@'localhost';

SET DEFAULT ROLE 'customer_role'       FOR 'demo_customer'@'localhost';
SET DEFAULT ROLE 'branch_staff_role'   FOR 'demo_staff'@'localhost';
SET DEFAULT ROLE 'branch_manager_role' FOR 'demo_manager'@'localhost';

FLUSH PRIVILEGES;

-- =====================================================================
-- LIVE VERIFICATION - run these as each demo user to prove the
-- boundaries are real, not just documented. (See companion .md report
-- for the actual observed results - every line below was executed.)
-- =====================================================================

-- As demo_customer (expect ALLOWED):
--   mysql -u demo_customer -pCustPass123! car_rental_db -e "SELECT * FROM vw_fleet_availability;"
--   mysql -u demo_customer -pCustPass123! car_rental_db -e "INSERT INTO Reservation (customer_id, category_id, pickup_branch_id, return_branch_id, pickup_date, expected_return_date) VALUES (2, 1, 1, 1, NOW(), DATE_ADD(NOW(), INTERVAL 2 DAY));"

-- As demo_customer (expect DENIED):
--   mysql -u demo_customer -pCustPass123! car_rental_db -e "UPDATE Vehicle SET status='Retired' WHERE vehicle_id=1;"
--   mysql -u demo_customer -pCustPass123! car_rental_db -e "INSERT INTO Damage (rental_id, description, repair_cost, charged_amount) VALUES (1, 'test', 0, 0);"
--   mysql -u demo_customer -pCustPass123! car_rental_db -e "UPDATE Customer SET license_no='FAKE123' WHERE customer_id=1;"

-- As demo_staff (expect ALLOWED):
--   mysql -u demo_staff -pStaffPass123! car_rental_db -e "UPDATE Vehicle SET status='Available' WHERE vehicle_id=1;"
--   mysql -u demo_staff -pStaffPass123! car_rental_db -e "INSERT INTO Payment (invoice_id, amount, payment_mode) VALUES (1, 100, 'Cash');"

-- As demo_staff (expect DENIED):
--   mysql -u demo_staff -pStaffPass123! car_rental_db -e "INSERT INTO RatePlan (category_id, plan_name, daily_rate, weekly_rate) VALUES (1, 'Test Plan', 999, 5000);"
--   mysql -u demo_staff -pStaffPass123! car_rental_db -e "UPDATE Vehicle SET make='Toyota' WHERE vehicle_id=1;"

-- As demo_manager (expect ALLOWED):
--   mysql -u demo_manager -pMgrPass123! car_rental_db -e "SELECT * FROM vw_branch_revenue;"
--   mysql -u demo_manager -pMgrPass123! car_rental_db -e "UPDATE Vehicle SET make='Toyota' WHERE vehicle_id=1;"
--   mysql -u demo_manager -pMgrPass123! car_rental_db -e "INSERT INTO RatePlan (category_id, plan_name, daily_rate, weekly_rate) VALUES (1, 'Test Plan', 999, 5000);"

-- As demo_manager (expect DENIED):
--   mysql -u demo_manager -pMgrPass123! car_rental_db -e "DELETE FROM Invoice WHERE invoice_id=1;"

-- =====================================================================
-- END OF RBAC SCRIPT
-- =====================================================================
