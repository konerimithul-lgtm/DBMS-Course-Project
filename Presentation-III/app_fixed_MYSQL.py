
import importlib
import tkinter as tk
from tkinter import ttk, messagebox
from datetime import datetime

# Import mysql.connector lazily so the app can still start with a helpful error
# if the dependency is not installed in the current Python environment.
mysql = None
try:
    mysql = importlib.import_module("mysql.connector")
except ModuleNotFoundError:
    mysql = None

# ============================================================
# CAR RENTAL RESERVATION & VEHICLE RETURN MANAGEMENT SYSTEM
# Final Presentation-III UI
# Python + Tkinter + MySQL
# ============================================================

DB_CONFIG = {
    "host": "localhost",
    "port": 3306,
    "user": "root",
    "password": "Mithul&3596",
    "database": "car_rental_db",
}

TABLES = {
    "Branch": [
        ("branch_id","INT","PK / Auto",""), ("branch_name","VARCHAR(80)","NOT NULL",""),
        ("city","VARCHAR(50)","NOT NULL",""), ("address","VARCHAR(150)","NULL",""),
        ("phone","VARCHAR(15)","NOT NULL","")
    ],
    "VehicleCategory": [
        ("category_id","INT","PK / Auto",""), ("category_name","VARCHAR(40)","UNIQUE / NOT NULL",""),
        ("description","VARCHAR(150)","NULL","")
    ],
    "Vehicle": [
        ("vehicle_id","INT","PK / Auto",""), ("registration_no","VARCHAR(15)","UNIQUE / NOT NULL",""),
        ("category_id","INT","FK / NOT NULL","VehicleCategory"), ("branch_id","INT","FK / NOT NULL","Branch"),
        ("make","VARCHAR(40)","NOT NULL",""), ("model","VARCHAR(40)","NOT NULL",""),
        ("year","INT","CHECK 1990-2100",""), ("color","VARCHAR(20)","NULL",""),
        ("current_odometer","INT","CHECK >= 0",""), ("status","VARCHAR(15)","DEFAULT Available","Available/Rented/Maintenance/Retired")
    ],
    "Customer": [
        ("customer_id","INT","PK / Auto",""), ("full_name","VARCHAR(80)","NOT NULL",""),
        ("dob","DATE","NOT NULL",""), ("phone","VARCHAR(15)","UNIQUE / NOT NULL",""),
        ("email","VARCHAR(80)","UNIQUE",""), ("license_no","VARCHAR(20)","UNIQUE / NOT NULL",""),
        ("license_expiry","DATE","NOT NULL",""), ("address","VARCHAR(150)","NULL","")
    ],
    "RatePlan": [
        ("rate_plan_id","INT","PK / Auto",""), ("category_id","INT","FK / NOT NULL","VehicleCategory"),
        ("plan_name","VARCHAR(40)","NOT NULL",""), ("daily_rate","DECIMAL(10,2)","CHECK > 0",""),
        ("weekly_rate","DECIMAL(10,2)","CHECK > 0",""), ("extra_km_rate","DECIMAL(6,2)","CHECK >= 0",""),
        ("late_fee_per_hour","DECIMAL(6,2)","CHECK >= 0","")
    ],
    "Reservation": [
        ("reservation_id","INT","PK / Auto",""), ("customer_id","INT","FK / NOT NULL","Customer"),
        ("category_id","INT","FK / NOT NULL","VehicleCategory"), ("pickup_branch_id","INT","FK / NOT NULL","Branch"),
        ("return_branch_id","INT","FK / NOT NULL","Branch"), ("reservation_date","DATETIME","DEFAULT CURRENT_TIMESTAMP",""),
        ("pickup_date","DATETIME","NOT NULL",""), ("expected_return_date","DATETIME","NOT NULL",""),
        ("status","VARCHAR(15)","DEFAULT Booked","Booked/Cancelled/Completed/Converted")
    ],
    "Rental": [
        ("rental_id","INT","PK / Auto",""), ("reservation_id","INT","FK / NULL","Reservation / walk-in"),
        ("vehicle_id","INT","FK / NOT NULL","Vehicle"), ("customer_id","INT","FK / NOT NULL","Customer"),
        ("rate_plan_id","INT","FK / NOT NULL","RatePlan"), ("pickup_branch_id","INT","FK / NOT NULL","Branch"),
        ("return_branch_id","INT","FK / NOT NULL","Branch"), ("pickup_datetime","DATETIME","NOT NULL",""),
        ("expected_return_datetime","DATETIME","NOT NULL",""), ("actual_return_datetime","DATETIME","NULL",""),
        ("status","VARCHAR(15)","DEFAULT Active","Active/Returned/Overdue")
    ],
    "Inspection": [
        ("inspection_id","INT","PK / Auto",""), ("rental_id","INT","FK / NOT NULL","Rental"),
        ("inspection_type","VARCHAR(10)","CHECK","Pickup/Return"), ("inspection_datetime","DATETIME","DEFAULT CURRENT_TIMESTAMP",""),
        ("odometer_reading","INT","CHECK >= 0",""), ("fuel_level_percent","INT","CHECK 0-100",""),
        ("exterior_condition","VARCHAR(20)","DEFAULT Good",""), ("notes","VARCHAR(200)","NULL",""),
        ("inspected_by","VARCHAR(60)","NULL","")
    ],
    "Damage": [
        ("damage_id","INT","PK / Auto",""), ("rental_id","INT","FK / NOT NULL","Rental"),
        ("inspection_id","INT","FK / NULL","Inspection"), ("description","VARCHAR(200)","NOT NULL",""),
        ("repair_cost","DECIMAL(10,2)","CHECK >= 0",""), ("charged_amount","DECIMAL(10,2)","CHECK >= 0","")
    ],
    "Invoice": [
        ("invoice_id","INT","PK / Auto",""), ("rental_id","INT","FK / UNIQUE / NOT NULL","Rental"),
        ("invoice_date","DATETIME","DEFAULT CURRENT_TIMESTAMP",""), ("base_charge","DECIMAL(10,2)","CHECK >= 0",""),
        ("extra_km_charge","DECIMAL(10,2)","CHECK >= 0",""), ("late_fee","DECIMAL(10,2)","CHECK >= 0",""),
        ("damage_charge","DECIMAL(10,2)","CHECK >= 0",""), ("tax_amount","DECIMAL(10,2)","CHECK >= 0",""),
        ("total_amount","DECIMAL(10,2)","CHECK >= 0","")
    ],
    "Payment": [
        ("payment_id","INT","PK / Auto",""), ("invoice_id","INT","FK / NOT NULL","Invoice"),
        ("payment_date","DATETIME","DEFAULT CURRENT_TIMESTAMP",""), ("amount","DECIMAL(10,2)","CHECK > 0",""),
        ("payment_mode","VARCHAR(15)","CHECK","Cash/Card/UPI/NetBanking"), ("transaction_ref","VARCHAR(40)","NULL","")
    ],
}

STATUS_FIELDS = {
    "Vehicle": {"status":["Available","Rented","Maintenance","Retired"]},
    "Reservation": {"status":["Booked","Cancelled","Completed","Converted"]},
    "Rental": {"status":["Active","Returned","Overdue"]},
    "Inspection": {"inspection_type":["Pickup","Return"]},
    "Payment": {"payment_mode":["Cash","Card","UPI","NetBanking"]},
}

class Database:
    def __init__(self):
        self.conn = None
    def connect(self):
        self.conn = mysql.connect(**DB_CONFIG)
        return self.conn
    def ensure(self):
        if self.conn is None or not self.conn.is_connected():
            self.connect()
    def execute(self, sql, params=(), fetch=False):
        self.ensure()
        cur = self.conn.cursor()
        try:
            cur.execute(sql, params)
            if fetch:
                rows = cur.fetchall()
                cols = cur.column_names
                return cols, rows
            self.conn.commit()
            return cur.lastrowid, cur.rowcount
        except Exception:
            self.conn.rollback()
            raise
        finally:
            cur.close()

db = Database()

def now_value():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Car Rental Reservation & Vehicle Return Management System")
        self.geometry("1500x900")
        self.minsize(1200,700)
        self.configure(bg="#eef2f7")
        self.style = ttk.Style(self)
        try: self.style.theme_use("clam")
        except: pass
        self.style.configure("Treeview", rowheight=28, font=("Segoe UI", 9))
        self.style.configure("Treeview.Heading", font=("Segoe UI", 9, "bold"))
        self.style.configure("TButton", font=("Segoe UI", 9, "bold"))
        self.style.configure("Title.TLabel", font=("Segoe UI", 22, "bold"))
        self.style.configure("Sub.TLabel", font=("Segoe UI", 10))
        self.build()

    def build(self):
        header = tk.Frame(self, bg="#14213d", height=76)
        header.pack(fill="x")
        tk.Label(header, text="CAR RENTAL", fg="white", bg="#14213d",
                 font=("Segoe UI",20,"bold")).pack(side="left", padx=25, pady=18)
        tk.Label(header, text="Reservation & Vehicle Return Management System",
                 fg="#cbd5e1", bg="#14213d", font=("Segoe UI",11)).pack(side="left", pady=22)
        tk.Label(header, text="AIML Panthers  •  Koneri Mithul  •  25WU0102129",
                 fg="white", bg="#14213d", font=("Segoe UI",9,"bold")).pack(side="right", padx=20)

        self.nb = ttk.Notebook(self)
        self.nb.pack(fill="both", expand=True, padx=12, pady=12)

        self.dashboard_tab()
        for t in TABLES:
            self.table_tab(t)
        self.availability_tab()
        self.reports_tab()

        footer=tk.Label(self,text="MySQL • 3NF • PK / FK / UNIQUE / NOT NULL / CHECK / DEFAULT • Transaction-aware CRUD",
                        bg="#14213d",fg="white",font=("Segoe UI",9))
        footer.pack(fill="x")

    def dashboard_tab(self):
        f=ttk.Frame(self.nb,padding=20); self.nb.add(f,text="🏠 Dashboard")
        ttk.Label(f,text="Database Control Center",style="Title.TLabel").pack(anchor="w")
        ttk.Label(f,text="Live summary from MySQL. Use the tabs above for complete CRUD on all 11 tables.",
                  style="Sub.TLabel").pack(anchor="w",pady=(4,20))
        self.cards={}
        row=ttk.Frame(f); row.pack(fill="x")
        for table,label in [("Branch","Branches"),("Vehicle","Vehicles"),("Customer","Customers"),
                            ("Reservation","Reservations"),("Rental","Rentals"),("Invoice","Invoices"),("Payment","Payments")]:
            card=ttk.LabelFrame(row,text=label,padding=18); card.pack(side="left",fill="x",expand=True,padx=5)
            v=ttk.Label(card,text="—",font=("Segoe UI",25,"bold")); v.pack()
            self.cards[table]=v
        ttk.Button(f,text="↻ Refresh Dashboard",command=self.refresh_dashboard).pack(anchor="e",pady=15)
        self.dashboard_status=ttk.Label(f,text="Connect to MySQL to load live counts.")
        self.dashboard_status.pack(anchor="w")
        self.refresh_dashboard()

    def refresh_dashboard(self):
        ok=0
        for table,v in self.cards.items():
            try:
                _,rows=db.execute(f"SELECT COUNT(*) FROM {table}",fetch=True)
                v.config(text=str(rows[0][0])); ok+=1
            except Exception:
                v.config(text="—")
        self.dashboard_status.config(text=f"Live database connected: {ok}/7 summary counters loaded." if ok else
                                    "MySQL not connected. Edit DB_CONFIG at the top of app.py.")

    def table_tab(self, table):
        f=ttk.Frame(self.nb,padding=10); self.nb.add(f,text=table)
        top=ttk.Frame(f); top.pack(fill="x")
        ttk.Label(top,text=table+" Management",style="Title.TLabel").pack(side="left")
        ttk.Label(top,text="  Full table structure / CRUD",style="Sub.TLabel").pack(side="left",pady=8)
        body=ttk.PanedWindow(f,orient="vertical"); body.pack(fill="both",expand=True,pady=10)
        form=ttk.LabelFrame(body,text="Record Details",padding=10); grid=ttk.Frame(form); grid.pack(fill="x")
        body.add(form,weight=0)
        view=ttk.Frame(body); body.add(view,weight=1)

        vars_={}
        for i,(col,typ,key,detail) in enumerate(TABLES[table]):
            r=i//3; c=(i%3)*2
            ttk.Label(grid,text=f"{col}  [{typ}]",font=("Segoe UI",8,"bold")).grid(row=r,column=c,padx=5,pady=5,sticky="w")
            var=tk.StringVar()
            vars_[col]=var
            if col in STATUS_FIELDS.get(table,{}):
                w=ttk.Combobox(grid,textvariable=var,values=STATUS_FIELDS[table][col],state="readonly",width=25)
                w.grid(row=r,column=c+1,padx=5,pady=5,sticky="ew")
            else:
                w=ttk.Entry(grid,textvariable=var,width=28)
                w.grid(row=r,column=c+1,padx=5,pady=5,sticky="ew")
            if "PK / Auto" in key:
                w.config(state="disabled")
        for c in range(6): grid.columnconfigure(c,weight=1)

        cols=[x[0] for x in TABLES[table]]
        tree=ttk.Treeview(view,columns=cols,show="headings")
        vs=ttk.Scrollbar(view,orient="vertical",command=tree.yview); hs=ttk.Scrollbar(view,orient="horizontal",command=tree.xview)
        tree.configure(yscrollcommand=vs.set,xscrollcommand=hs.set)
        tree.grid(row=0,column=0,sticky="nsew"); vs.grid(row=0,column=1,sticky="ns"); hs.grid(row=1,column=0,sticky="ew")
        view.rowconfigure(0,weight=1); view.columnconfigure(0,weight=1)
        for col in cols:
            tree.heading(col,text=col)
            tree.column(col,width=max(115,min(190,9*len(col)+50)))
        def select(_):
            item=tree.focus()
            if not item:return
            vals=tree.item(item,"values")
            for i,col in enumerate(cols):
                if col in vars_:
                    vars_[col].set(vals[i])
        tree.bind("<<TreeviewSelect>>",select)
        def load_table():
            for x in tree.get_children(): tree.delete(x)
            try:
                c,rows=db.execute(f"SELECT {', '.join(cols)} FROM {table} ORDER BY 1 DESC",fetch=True)
                for r in rows: tree.insert("", "end", values=[("" if x is None else x) for x in r])
            except Exception as e:
                # Keep the UI usable even before DB setup.
                if not str(e).startswith("2003") and "Unknown database" not in str(e):
                    pass
        load_table()

        btn=ttk.Frame(form); btn.pack(fill="x",pady=(8,0))
        ttk.Button(btn,text="INSERT / SAVE",command=lambda:self.insert_record(table,vars_,load_table)).pack(side="left",padx=3)
        ttk.Button(btn,text="UPDATE",command=lambda:self.update_record(table,vars_,load_table)).pack(side="left",padx=3)
        ttk.Button(btn,text="DELETE",command=lambda:self.delete_record(table,vars_,load_table)).pack(side="left",padx=3)
        ttk.Button(btn,text="CLEAR",command=lambda:self.clear_vars(vars_)).pack(side="left",padx=3)
        ttk.Button(btn,text="REFRESH",command=load_table).pack(side="left",padx=3)
        ttk.Label(btn,text="Select a row to load it into the form.").pack(side="right")

    def clear_vars(self,vs):
        for v in vs.values(): v.set("")

    def payload(self,table,vs,include_pk=False):
        cols=[]; vals=[]
        for col,typ,key,detail in TABLES[table]:
            if not include_pk and "PK / Auto" in key: continue
            val=vs[col].get().strip()
            if val=="":
                if "DEFAULT" in key or "NULL" in key: continue
                raise ValueError(f"{col} is required.")
            cols.append(col); vals.append(val)
        return cols,vals

    def insert_record(self,table,vs,refresh):
        try:
            cols,vals=self.payload(table,vs)
            ph=",".join(["%s"]*len(cols))
            db.execute(f"INSERT INTO {table} ({','.join(cols)}) VALUES ({ph})",vals)
            refresh(); self.clear_vars(vs)
            messagebox.showinfo("Success",f"{table} record inserted successfully and committed to MySQL.")
            self.refresh_dashboard()
        except Exception as e: messagebox.showerror("Insert Failed",str(e))

    def update_record(self,table,vs,refresh):
        pk=TABLES[table][0][0]; pkval=vs[pk].get().strip()
        if not pkval: messagebox.showwarning("Select Record","Select a row first."); return
        try:
            cols,vals=self.payload(table,vs)
            assignments=",".join(f"{c}=%s" for c in cols)
            db.execute(f"UPDATE {table} SET {assignments} WHERE {pk}=%s",vals+[pkval])
            refresh(); messagebox.showinfo("Success",f"{table} record updated.")
            self.refresh_dashboard()
        except Exception as e: messagebox.showerror("Update Failed",str(e))

    def delete_record(self,table,vs,refresh):
        pk=TABLES[table][0][0]; pkval=vs[pk].get().strip()
        if not pkval: messagebox.showwarning("Select Record","Select a row first."); return
        if not messagebox.askyesno("Confirm Delete",f"Delete {table} ID {pkval}? This uses the real MySQL database."): return
        try:
            db.execute(f"DELETE FROM {table} WHERE {pk}=%s",(pkval,))
            refresh(); self.clear_vars(vs)
            messagebox.showinfo("Deleted",f"{table} record deleted and the change is reflected in MySQL.")
            self.refresh_dashboard()
        except Exception as e: messagebox.showerror("Delete Failed",str(e))

    def availability_tab(self):
        f=ttk.Frame(self.nb,padding=15); self.nb.add(f,text="🔎 Availability")
        ttk.Label(f,text="Fleet Availability Search",style="Title.TLabel").pack(anchor="w")
        ttk.Label(f,text="Search currently available vehicles by branch and category.",style="Sub.TLabel").pack(anchor="w",pady=4)
        controls=ttk.Frame(f); controls.pack(fill="x",pady=15)
        branch=tk.StringVar(); cat=tk.StringVar()
        ttk.Label(controls,text="Branch ID").pack(side="left"); ttk.Entry(controls,textvariable=branch,width=12).pack(side="left",padx=5)
        ttk.Label(controls,text="Category ID").pack(side="left",padx=(20,0)); ttk.Entry(controls,textvariable=cat,width=12).pack(side="left",padx=5)
        tree=ttk.Treeview(f,columns=("vehicle_id","registration_no","category","branch","make","model","year","color","odometer","status"),show="headings")
        tree.pack(fill="both",expand=True)
        for c in tree["columns"]: tree.heading(c,text=c); tree.column(c,width=130)
        def search():
            for x in tree.get_children(): tree.delete(x)
            sql="""SELECT v.vehicle_id,v.registration_no,c.category_name,b.branch_name,v.make,v.model,
                           v.year,v.color,v.current_odometer,v.status
                    FROM Vehicle v JOIN VehicleCategory c ON v.category_id=c.category_id
                    JOIN Branch b ON v.branch_id=b.branch_id
                    WHERE v.status='Available'
                      AND (%s='' OR v.branch_id=%s)
                      AND (%s='' OR v.category_id=%s)
                    ORDER BY v.vehicle_id"""
            try:
                _,rows=db.execute(sql,(branch.get(),branch.get(),cat.get(),cat.get()),fetch=True)
                for r in rows: tree.insert("", "end", values=r)
            except Exception as e: messagebox.showerror("Search Failed",str(e))
        ttk.Button(controls,text="SEARCH",command=search).pack(side="left",padx=15)

    def reports_tab(self):
        f=ttk.Frame(self.nb,padding=12); self.nb.add(f,text="📊 Reports")
        ttk.Label(f,text="Management Reports",style="Title.TLabel").pack(anchor="w")
        controls=ttk.Frame(f); controls.pack(fill="x",pady=10)
        reports=[
            ("Fleet Availability","SELECT * FROM vw_fleet_availability"),
            ("Overdue Rentals","SELECT * FROM vw_overdue_rentals"),
            ("Customer History","SELECT * FROM vw_customer_rental_history"),
            ("Branch Revenue","SELECT * FROM vw_branch_revenue"),
            ("Vehicle Utilization","SELECT * FROM vw_vehicle_utilization"),
            ("Damage Report","SELECT * FROM vw_damage_report"),
        ]
        tree=ttk.Treeview(f,show="headings"); tree.pack(fill="both",expand=True)
        def run(sql):
            try:
                cols,rows=db.execute(sql,fetch=True)
                tree.delete(*tree.get_children())
                tree["columns"]=cols
                for c in cols:
                    tree.heading(c,text=c); tree.column(c,width=max(120,8*len(c)+40))
                for r in rows: tree.insert("", "end",values=r)
            except Exception as e: messagebox.showerror("Report Failed",str(e))
        for label,sql in reports:
            ttk.Button(controls,text=label,command=lambda s=sql:run(s)).pack(side="left",padx=3)
        ttk.Label(f,text="These reports correspond to the required fleet, overdue, utilization, damage, branch revenue and customer-history outputs.",
                  style="Sub.TLabel").pack(anchor="w",pady=8)

if __name__=="__main__":
    try:
        app=App()
        app.mainloop()
    except Exception as e:
        messagebox.showerror("Application Error",str(e))
