-- =====================================================================
-- CAR RENTAL RESERVATION AND VEHICLE RETURN MANAGEMENT SYSTEM
-- SAMPLE DATA ONLY - run this AFTER your tables already exist
-- (i.e. after the CREATE TABLE / CREATE TRIGGER part of car_rental_review2.sql)
-- =====================================================================

USE car_rental_db;

-- Deliberately includes: available / rented / maintenance vehicles,
-- multiple branches & categories, customers with rental history,
-- a currently-active rental, a currently-overdue rental, a returned
-- rental with damage, and both fully-paid and partially-paid invoices.

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
-- Quick sanity check after running - row counts should match:
-- Branch=4, VehicleCategory=4, Vehicle=12, Customer=9, RatePlan=5,
-- Reservation=10, Rental=9, Inspection=16, Damage=3, Invoice=7, Payment=8
-- =====================================================================
-- SELECT 'Branch' t, COUNT(*) c FROM Branch UNION ALL
-- SELECT 'Vehicle', COUNT(*) FROM Vehicle UNION ALL
-- SELECT 'Customer', COUNT(*) FROM Customer UNION ALL
-- SELECT 'Rental', COUNT(*) FROM Rental UNION ALL
-- SELECT 'Invoice', COUNT(*) FROM Invoice UNION ALL
-- SELECT 'Payment', COUNT(*) FROM Payment;
