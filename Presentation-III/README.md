# Car Rental Reservation & Vehicle Return Management System — Final UI

## Student
- Name: Koneri Mithul
- Roll No: 25WU0102129
- Class: AIML Panthers
- Guide: Dr. Kiran Mayee Adavala

## Stack
Python 3 + Tkinter/ttk + MySQL + mysql-connector-python

## Included database entities — all 11
1. Branch
2. VehicleCategory
3. Vehicle
4. Customer
5. RatePlan
6. Reservation
7. Rental
8. Inspection
9. Damage
10. Invoice
11. Payment

The UI includes every column/attribute from the project schema, including PKs, FKs, UNIQUE fields, CHECK/default/status fields, date/time fields and financial fields.

## Setup
1. Install MySQL 8.x.
2. Run the project's `car_rental_schema.sql` to create `car_rental_db`.
3. Load the sample data SQL used in Review 2.
4. Install Python dependency:
   `pip install mysql-connector-python`
5. Open `app.py`.
6. Change `DB_CONFIG["password"]` to your MySQL root password.
7. Run:
   `python app.py`

## Presentation III demo
Use this exact flow:
1. Dashboard — show live counts.
2. Customer tab — INSERT a new test customer.
3. Show the new row in the UI.
4. Verify with MySQL `SELECT * FROM Customer`.
5. VIEW records.
6. DELETE the test customer.
7. Refresh and show it is gone from MySQL.
8. Show Vehicle / Reservation / Rental / Inspection / Damage / Invoice / Payment tabs.
9. Availability search.
10. Reports.

## Important
This UI is designed to use the real MySQL database. It is not a static/mock interface.
