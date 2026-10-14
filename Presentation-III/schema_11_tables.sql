CREATE DATABASE IF NOT EXISTS car_rental_db;
USE car_rental_db;

CREATE TABLE IF NOT EXISTS Branch (
 branch_id INT AUTO_INCREMENT PRIMARY KEY, branch_name VARCHAR(80) NOT NULL,
 city VARCHAR(50) NOT NULL, address VARCHAR(150), phone VARCHAR(15) NOT NULL);

CREATE TABLE IF NOT EXISTS VehicleCategory (
 category_id INT AUTO_INCREMENT PRIMARY KEY, category_name VARCHAR(40) NOT NULL UNIQUE,
 description VARCHAR(150));

CREATE TABLE IF NOT EXISTS Vehicle (
 vehicle_id INT AUTO_INCREMENT PRIMARY KEY, registration_no VARCHAR(15) NOT NULL UNIQUE,
 category_id INT NOT NULL, branch_id INT NOT NULL, make VARCHAR(40) NOT NULL,
 model VARCHAR(40) NOT NULL, year INT NOT NULL CHECK(year BETWEEN 1990 AND 2100),
 color VARCHAR(20), current_odometer INT NOT NULL DEFAULT 0 CHECK(current_odometer>=0),
 status VARCHAR(15) NOT NULL DEFAULT 'Available'
 CHECK(status IN('Available','Rented','Maintenance','Retired')),
 FOREIGN KEY(category_id) REFERENCES VehicleCategory(category_id),
 FOREIGN KEY(branch_id) REFERENCES Branch(branch_id));

CREATE TABLE IF NOT EXISTS Customer (
 customer_id INT AUTO_INCREMENT PRIMARY KEY, full_name VARCHAR(80) NOT NULL,
 dob DATE NOT NULL, phone VARCHAR(15) NOT NULL UNIQUE, email VARCHAR(80) UNIQUE,
 license_no VARCHAR(20) NOT NULL UNIQUE, license_expiry DATE NOT NULL, address VARCHAR(150));

CREATE TABLE IF NOT EXISTS RatePlan (
 rate_plan_id INT AUTO_INCREMENT PRIMARY KEY, category_id INT NOT NULL, plan_name VARCHAR(40) NOT NULL,
 daily_rate DECIMAL(10,2) NOT NULL CHECK(daily_rate>0), weekly_rate DECIMAL(10,2) NOT NULL CHECK(weekly_rate>0),
 extra_km_rate DECIMAL(6,2) NOT NULL DEFAULT 0 CHECK(extra_km_rate>=0),
 late_fee_per_hour DECIMAL(6,2) NOT NULL DEFAULT 0 CHECK(late_fee_per_hour>=0),
 FOREIGN KEY(category_id) REFERENCES VehicleCategory(category_id));

CREATE TABLE IF NOT EXISTS Reservation (
 reservation_id INT AUTO_INCREMENT PRIMARY KEY, customer_id INT NOT NULL, category_id INT NOT NULL,
 pickup_branch_id INT NOT NULL, return_branch_id INT NOT NULL,
 reservation_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, pickup_date DATETIME NOT NULL,
 expected_return_date DATETIME NOT NULL,
 status VARCHAR(15) NOT NULL DEFAULT 'Booked'
 CHECK(status IN('Booked','Cancelled','Completed','Converted')),
 FOREIGN KEY(customer_id) REFERENCES Customer(customer_id), FOREIGN KEY(category_id) REFERENCES VehicleCategory(category_id),
 FOREIGN KEY(pickup_branch_id) REFERENCES Branch(branch_id), FOREIGN KEY(return_branch_id) REFERENCES Branch(branch_id),
 CHECK(expected_return_date>pickup_date));

CREATE TABLE IF NOT EXISTS Rental (
 rental_id INT AUTO_INCREMENT PRIMARY KEY, reservation_id INT NULL, vehicle_id INT NOT NULL,
 customer_id INT NOT NULL, rate_plan_id INT NOT NULL, pickup_branch_id INT NOT NULL,
 return_branch_id INT NOT NULL, pickup_datetime DATETIME NOT NULL,
 expected_return_datetime DATETIME NOT NULL, actual_return_datetime DATETIME NULL,
 status VARCHAR(15) NOT NULL DEFAULT 'Active' CHECK(status IN('Active','Returned','Overdue')),
 FOREIGN KEY(reservation_id) REFERENCES Reservation(reservation_id), FOREIGN KEY(vehicle_id) REFERENCES Vehicle(vehicle_id),
 FOREIGN KEY(customer_id) REFERENCES Customer(customer_id), FOREIGN KEY(rate_plan_id) REFERENCES RatePlan(rate_plan_id),
 FOREIGN KEY(pickup_branch_id) REFERENCES Branch(branch_id), FOREIGN KEY(return_branch_id) REFERENCES Branch(branch_id),
 CHECK(actual_return_datetime IS NULL OR actual_return_datetime>pickup_datetime),
 CHECK(expected_return_datetime>pickup_datetime));

CREATE TABLE IF NOT EXISTS Inspection (
 inspection_id INT AUTO_INCREMENT PRIMARY KEY, rental_id INT NOT NULL,
 inspection_type VARCHAR(10) NOT NULL CHECK(inspection_type IN('Pickup','Return')),
 inspection_datetime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 odometer_reading INT NOT NULL CHECK(odometer_reading>=0),
 fuel_level_percent INT NOT NULL CHECK(fuel_level_percent BETWEEN 0 AND 100),
 exterior_condition VARCHAR(20) DEFAULT 'Good', notes VARCHAR(200), inspected_by VARCHAR(60),
 FOREIGN KEY(rental_id) REFERENCES Rental(rental_id));

CREATE TABLE IF NOT EXISTS Damage (
 damage_id INT AUTO_INCREMENT PRIMARY KEY, rental_id INT NOT NULL, inspection_id INT NULL,
 description VARCHAR(200) NOT NULL, repair_cost DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK(repair_cost>=0),
 charged_amount DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK(charged_amount>=0),
 FOREIGN KEY(rental_id) REFERENCES Rental(rental_id), FOREIGN KEY(inspection_id) REFERENCES Inspection(inspection_id));

CREATE TABLE IF NOT EXISTS Invoice (
 invoice_id INT AUTO_INCREMENT PRIMARY KEY, rental_id INT NOT NULL UNIQUE,
 invoice_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, base_charge DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK(base_charge>=0),
 extra_km_charge DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK(extra_km_charge>=0),
 late_fee DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK(late_fee>=0),
 damage_charge DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK(damage_charge>=0),
 tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK(tax_amount>=0),
 total_amount DECIMAL(10,2) NOT NULL CHECK(total_amount>=0),
 FOREIGN KEY(rental_id) REFERENCES Rental(rental_id));

CREATE TABLE IF NOT EXISTS Payment (
 payment_id INT AUTO_INCREMENT PRIMARY KEY, invoice_id INT NOT NULL,
 payment_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, amount DECIMAL(10,2) NOT NULL CHECK(amount>0),
 payment_mode VARCHAR(15) NOT NULL CHECK(payment_mode IN('Cash','Card','UPI','NetBanking')),
 transaction_ref VARCHAR(40), FOREIGN KEY(invoice_id) REFERENCES Invoice(invoice_id));
