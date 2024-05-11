-- Entities

CREATE TABLE IF NOT EXISTS Customers (
    email   TEXT PRIMARY KEY,
    address TEXT NOT NULL,
    dob     DATE NOT NULL,
    phone   TEXT NOT NULL,
    fsname  TEXT,
    lsname  TEXT NOT NULL,
    CONSTRAINT dob_check CHECK(dob < NOW())
);

CREATE TABLE IF NOT EXISTS Locations (
    zip   INT  PRIMARY KEY,
    laddr TEXT NOT NULL,
    lname TEXT UNIQUE
);

CREATE TABLE IF NOT EXISTS Employees (
    eid    INT  PRIMARY KEY,
    ename  TEXT NOT NULL,
    ephone TEXT NOT NULL,
    lzip   INT  NOT NULL,
    CONSTRAINT l_fk FOREIGN KEY (lzip) REFERENCES Locations (zip)
);

CREATE TABLE IF NOT EXISTS Drivers (
    eid  INT  PRIMARY KEY
        REFERENCES Employees (eid) ON DELETE CASCADE,
    pdvl TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS CarModels (
    brand    TEXT,
    model    TEXT,
    capacity INT   NOT NULL,
    deposit  MONEY NOT NULL,
    daily    MONEY NOT NULL,
    CONSTRAINT pk PRIMARY KEY (brand, model)
);

CREATE TABLE IF NOT EXISTS CarDetails (
    plate TEXT PRIMARY KEY,
    color TEXT NOT NULL,
    pyear INT  NOT NULL,
    brand TEXT NOT NULL,
    model TEXT NOT NULL,
    zip   INT  NOT NULL,
    CONSTRAINT cm_fk FOREIGN KEY (brand, model) REFERENCES CarModels (brand, model),
    CONSTRAINT l_fk  FOREIGN KEY (zip)          REFERENCES Locations (zip)
);

CREATE TABLE IF NOT EXISTS Bookings (
    bid    INT  PRIMARY KEY,
    sdate  DATE NOT NULL,
    days   INT  NOT NULL,
    lzip   INT  NOT NULL,
    cbrand TEXT NOT NULL,
    cmodel TEXT NOT NULL,
    cemail TEXT NOT NULL,
    bdate  DATE NOT NULL,
    ccnum  TEXT NOT NULL,
    CONSTRAINT l_fk    FOREIGN KEY (lzip)           REFERENCES Locations (zip),
    CONSTRAINT cm_fk   FOREIGN KEY (cbrand, cmodel) REFERENCES CarModels (brand, model),
    CONSTRAINT c_fk    FOREIGN KEY (cemail)         REFERENCES Customers (email),
    CONSTRAINT bdate_c CHECK (bdate < sdate)
);

-- Aggregate

CREATE TABLE IF NOT EXISTS Assigns (
	bid   INT  PRIMARY KEY,
	plate TEXT,
	sdate DATE NOT NULL, 
	days  INT  NOT NULL,
	FOREIGN KEY (bid) REFERENCES Bookings (bid),
	FOREIGN KEY (plate) REFERENCES CarDetails (plate)
);

-- Relationships 

CREATE TABLE IF NOT EXISTS Hires (
    bid      INT  PRIMARY KEY,
    plate    TEXT,
    pdvl     TEXT NOT NULL,
    fromdate DATE NOT NULL,
    todate   DATE NOT NULL,
    ccnum    TEXT NOT NULL,
    sdate    DATE NOT NULL,
    days     INT  NOT NULL,
    CONSTRAINT a_fk    FOREIGN KEY (bid) REFERENCES Assigns (bid),
    CONSTRAINT d_fk    FOREIGN KEY (pdvl)       REFERENCES Drivers (pdvl),
    CONSTRAINT date_c  CHECK(fromdate >= sdate AND
                             todate >= sdate AND
                             fromdate <= sdate + days AND
                             todate <= sdate + days),
    CONSTRAINT plate_c CHECK(plate IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS Returned (
    ccnum TEXT NOT NULL, 
    cost  INT NOT NULL, 
    eid   INT, 
    bid   INT, 
    PRIMARY KEY (bid, eid),
    FOREIGN KEY (bid) REFERENCES Assigns (bid), 
    FOREIGN KEY (eid) REFERENCES Employees (eid),
    CONSTRAINT  ccnum_c CHECK(cost <= 0 OR ccnum IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS Handover (
	eid INT, 
	bid INT, 
	PRIMARY KEY (bid, eid),
	FOREIGN KEY (bid) REFERENCES Assigns(bid), 
	FOREIGN KEY (eid) REFERENCES Employees
);
