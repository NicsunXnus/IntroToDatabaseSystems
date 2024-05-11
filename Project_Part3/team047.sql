/*
Group #47
1. Sun Jun Yang Nicholas
- Contribution: Trigger 1, Trigger 4, Procedure 1
2. Lau Teng Hon
- Contribution: Trigger 3, Procedure 2, Function 1
3. Toh Wang Bin
- Contribution: Trigger 5, Procedure 3, Function 2
4. Tan Yi Long
- Contribution: Trigger 2, Trigger 6, Procedure 4, Function 2
*/

-- Helper method for checking overlaps
CREATE OR REPLACE FUNCTION is_overlap(s_date DATE, e_date DATE, s_date2 DATE, e_date2 DATE)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN s_date2 <= e_date AND s_date <= e_date2;
END;
$$ LANGUAGE plpgsql;

-- Start of Trigger 1
CREATE OR REPLACE FUNCTION check_double_booking()
RETURNS TRIGGER AS $func$
DECLARE
	overlapping_bookings INTEGER;
BEGIN
	-- Check for overlapping bookings for the same driver
	SELECT COUNT(*) INTO overlapping_bookings
	FROM Hires
	WHERE eid = NEW.eid
	AND is_overlap(fromdate, todate, NEW.fromdate, NEW.todate);
    
	-- If there are overlapping bookings, raise an exception
	IF overlapping_bookings > 0 THEN
    	RAISE EXCEPTION 'Driver is already booked for another assignment during this period';
	END IF;
    
	RETURN NEW;
END;
$func$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS prevent_double_booking ON Hires CASCADE;

CREATE TRIGGER prevent_double_booking
BEFORE INSERT ON Hires
FOR EACH ROW
EXECUTE FUNCTION check_double_booking();
-- End of Trigger 1

-- Start of Trigger 2
CREATE OR REPLACE FUNCTION assigns_function() RETURNS TRIGGER AS $$
DECLARE
    curs CURSOR FOR (SELECT * FROM Assigns A WHERE A.plate = NEW.plate);
    r RECORD;
    csdate DATE;
    cbdays INT;
    osdate DATE;
    obdays INT;
BEGIN
    SELECT B.sdate FROM Bookings B WHERE B.bid = NEW.bid INTO csdate;
    SELECT B.days FROM Bookings B WHERE B.bid = NEW.bid INTO cbdays;
    OPEN curs;
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;
        SELECT B.sdate FROM Bookings B WHERE B.bid = r.bid INTO osdate;
        SELECT B.days FROM Bookings B WHERE B.bid = r.bid INTO obdays;

        -- overlapping
        IF (is_overlap(csdate, csdate + cbdays - 1, osdate, osdate + obdays - 1)) THEN
            RETURN NULL;
        END IF;

    END LOOP;
    CLOSE curs;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS assigns_trigger ON Assigns CASCADE;

CREATE TRIGGER assigns_trigger
BEFORE INSERT ON Assigns
FOR EACH ROW EXECUTE FUNCTION assigns_function();
-- End of Trigger 2

-- Start of Trigger 3
CREATE OR REPLACE FUNCTION check_same_loc_func()
RETURNS TRIGGER AS $$
DECLARE
  employee_zip INT;
  booking_zip INT;
BEGIN
  SELECT zip FROM Employees WHERE Employees.eid = NEW.eid INTO employee_zip;
  SELECT zip FROM Bookings WHERE Bookings.bid = NEW.bid INTO booking_zip;

  IF employee_zip = booking_zip THEN
    RETURN NEW;
  ELSE
    RAISE NOTICE 'location does not match between employee and booking';
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS handover_trigger ON Handover CASCADE;

CREATE TRIGGER handover_trigger
BEFORE INSERT ON Handover
FOR EACH ROW EXECUTE FUNCTION check_same_loc_func();
-- End of Trigger 3

-- Start of Trigger 4
CREATE OR REPLACE FUNCTION check_assigned_car_details_same_as_booking()
RETURNS TRIGGER AS $func$
DECLARE
	same_details INTEGER;
BEGIN
	-- Check for bookings for same car details
	SELECT COUNT(*) INTO same_details
	FROM (SELECT brand,model from Bookings where NEW.bid = bid) booking_car_details join (select brand,model from CarDetails where NEW.plate = plate) car_details
    on booking_car_details.brand = car_details.brand
    AND booking_car_details.model = car_details.model;
    
	-- If there are different car details, raise an exception
	IF same_details <> 1 THEN
    	    -- RAISE EXCEPTION 'Booking''s car details does not match with assignment''s car details.';
           RETURN NULL;
	END IF;
    
	RETURN NEW;
END;
$func$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS  prevent_different_assigned_car_details ON Assigns CASCADE;

CREATE TRIGGER prevent_different_assigned_car_details
BEFORE INSERT ON Assigns
FOR EACH ROW
EXECUTE FUNCTION check_assigned_car_details_same_as_booking();
-- End of Trigger 4

-- Start of Trigger 5
CREATE OR REPLACE FUNCTION check_car_parked_location_same_as_booking()
RETURNS TRIGGER AS $$
DECLARE
  booking_zip INT;
  car_zip INT;
BEGIN
  -- retrieve the zip codes from Bookings and CarDetails
  SELECT b.zip INTO booking_zip FROM Bookings b WHERE b.bid = NEW.bid;
  SELECT c.zip INTO car_zip FROM CarDetails c WHERE c.plate = NEW.plate;
 
  -- if there are inconsistencies then raise notice and not insert
  IF booking_zip <> car_zip THEN
  RAISE NOTICE 'Booked car is not parked in same location as the booking site.';
  RETURN NULL;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS car_location_trigger ON Assigns CASCADE;

CREATE TRIGGER car_location_trigger
BEFORE INSERT ON Assigns
FOR EACH ROW EXECUTE FUNCTION check_car_parked_location_same_as_booking();
-- End of Trigger 5

-- Start of Trigger 6
CREATE OR REPLACE FUNCTION driver_hire_function() RETURNS TRIGGER AS $$
DECLARE
    sdate DATE;
    bdays INT;
BEGIN
    SELECT B.sdate FROM Bookings B WHERE NEW.bid = B.bid INTO sdate;
    SELECT B.days FROM Bookings B WHERE NEW.bid = B.bid INTO bdays;
    IF (NEW.fromdate >= sdate AND NEW.todate <= sdate + bdays) THEN
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS driver_hire_trigger ON Hires CASCADE;

CREATE OR REPLACE TRIGGER driver_hire_trigger
BEFORE INSERT ON Hires
FOR EACH ROW EXECUTE FUNCTION driver_hire_function();
-- End of Trigger 6

/*
Write your Routines Below
Comment out your routine if you cannot complete
the routine.
If any of your routine causes error (even those
that are incomplete), you may get 0 mark for P03.
*/
-- PROCEDURE 1
CREATE OR REPLACE PROCEDURE add_employees (
    eids INT[], enames TEXT[], ephones INT[], zips INT[], pdvls TEXT[]
) AS $$
DECLARE
	i INT;
BEGIN
   -- Check if arrays are not empty and have the same length
   IF array_length(eids, 1) = 0 THEN
RAISE EXCEPTION 'Array of employee IDs is empty';
   END IF;
   BEGIN
FOR i IN 1..array_length(eids, 1) LOOP
        	-- Insert employee
        	INSERT INTO Employees (eid, ename, ephone, zip)
        	VALUES (eids[i], enames[i], ephones[i], zips[i]);

        	-- Insert driver if pdvl is provided
        	IF pdvls[i] IS NOT NULL THEN
            	INSERT INTO Drivers (eid, pdvl) VALUES (eids[i], pdvls[i]);
        	END IF;
    	END LOOP;

  EXCEPTION
    WHEN others THEN
        -- Rollback transaction on error
        ROLLBACK;
        RAISE EXCEPTION 'Error occurred while adding employees';	
  END;
END;
$$ LANGUAGE plpgsql;

-- PROCEDURE 2
CREATE OR REPLACE PROCEDURE add_car (
  brand   TEXT   , model  TEXT   , capacity INT  ,
  deposit NUMERIC, daily  NUMERIC,
  plates  TEXT[] , colors TEXT[] , pyears   INT[], zips INT[]
) AS $$
DECLARE
  i INT;
BEGIN
  INSERT INTO CarModels (brand, model, capacity, deposit, daily)
  VALUES (brand, model, capacity, deposit, daily);

  IF ARRAY_LENGTH(plates, 1) > 0 THEN
    FOR i IN ARRAY_LOWER(plates, 1) .. ARRAY_UPPER(plates, 1) LOOP
      INSERT INTO CarDetails (plate, color, pyear, brand, model, zip)
      VALUES (plates[i], colors[i], pyears[i], brand, model, zips[i]);
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- PROCEDURE 3
CREATE OR REPLACE PROCEDURE return_car (
	parameter_bid INT, eid INT
) AS $$
DECLARE
-- variables to retrieve from Bookings
  num_days INT;
  car_brand TEXT;
  car_model TEXT;
-- variables to retrieve from CarDetails
  daily_cost INT;
  car_deposit INT;
  booking_ccnum TEXT;
-- other variables
  total_cost INT;
BEGIN

  SELECT b.days, b.brand, b.model, b.ccnum
  FROM Bookings b
  WHERE b.bid = parameter_bid
  INTO  num_days, car_brand, car_model, booking_ccnum;

  SELECT c.daily, c.deposit
  FROM CarModels c
  WHERE c.brand = car_brand
  AND c.model = car_model
  INTO daily_cost, car_deposit;

  total_cost := (daily_cost * num_days) - car_deposit;

  INSERT INTO Returned(bid, eid, ccnum, cost)
  VALUES (parameter_bid, eid, booking_ccnum, total_cost);

END;
$$ LANGUAGE plpgsql;

-- PROCEDURE 4
CREATE OR REPLACE PROCEDURE auto_assign () AS $$
DECLARE
    booking_curs CURSOR FOR (SELECT * FROM Bookings B WHERE B.bid NOT IN (SELECT A.bid FROM Assigns A) ORDER BY B.bid);
    car_curs CURSOR FOR (SELECT * FROM CarDetails ORDER BY plate);
    booking_r RECORD;
    car_r RECORD;
    inserted INT;
BEGIN
    OPEN booking_curs;
    OPEN car_curs;
    LOOP
        FETCH booking_curs INTO booking_r;
        EXIT WHEN NOT FOUND;
        inserted := 0;
        FETCH FIRST FROM car_curs INTO car_r;
        WHILE (FOUND AND inserted = 0) LOOP
            INSERT INTO Assigns(bid, plate)
            VALUES (booking_r.bid, car_r.plate);
            IF (booking_r.bid IN (SELECT A.bid FROM Assigns A)) THEN
                inserted := 1;
            END IF;
            FETCH car_curs INTO car_r;
        END LOOP;
    END LOOP;
    CLOSE car_curs;
    CLOSE booking_curs;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION 1
CREATE OR REPLACE FUNCTION compute_revenue (
  calc_sdate DATE, calc_edate DATE
) RETURNS NUMERIC AS $$
DECLARE 
  overlap_bookings RECORD;
  overlap_drivers RECORD;
  overlap_cars RECORD;
  booking_revenue INT := 0;
  driver_revenue INT := 0;
  car_cost INT := 0;
BEGIN
  FOR overlap_bookings IN
    SELECT DISTINCT daily, days
    FROM Bookings INNER JOIN CarModels on Bookings.brand=CarModels.brand AND Bookings.model=CarModels.model INNER JOIN Assigns on Bookings.bid=Assigns.bid
    WHERE is_overlap(calc_sdate, calc_edate, Bookings.sdate, Bookings.sdate + days - 1)
  LOOP
    booking_revenue := booking_revenue + (overlap_bookings.daily * overlap_bookings.days);
  END LOOP;

  FOR overlap_drivers IN
    SELECT fromdate, todate 
    FROM Hires
    WHERE is_overlap(calc_sdate, calc_edate, Hires.fromdate, Hires.todate)
  LOOP
    driver_revenue := driver_revenue + ((overlap_drivers.todate - overlap_drivers.fromdate + 1) * 10);
  END LOOP; 

  FOR overlap_cars IN
    SELECT DISTINCT plate
    FROM Bookings INNER JOIN Assigns ON Bookings.bid=Assigns.bid
    WHERE is_overlap(calc_sdate, calc_edate, Bookings.sdate, Bookings.sdate + days - 1)
  LOOP
    car_cost := car_cost + 100;
  END LOOP;

  return booking_revenue + driver_revenue - car_cost;
END;

$$ LANGUAGE plpgsql;

-- FUNCTION 2
CREATE OR REPLACE FUNCTION top_n_location (
	n INT, start_date DATE, end_date DATE
) RETURNS TABLE(lname TEXT, revenue NUMERIC, rank INT) AS $$
DECLARE
	curs CURSOR FOR
    	SELECT Lmain.lname AS lname,
        	fromBookings.bookingsRevenue + fromDrivers.driverRevenue + fromCars.carRevenue AS revenue
    	FROM
    	(SELECT L.zip,
        	COALESCE(bookingsIntermediate.revenue, 0) AS bookingsRevenue
    	FROM Locations L
    	LEFT JOIN
    	(SELECT B.zip,
        	COALESCE(SUM(M.daily * B.days), 0) AS revenue
    	FROM Bookings B, CarModels M, Assigns A
    	WHERE B.brand = M.brand AND
        	B.model = M.model AND
        	A.bid = B.bid AND
   		is_overlap(B.sdate, B.sdate + B.days - 1, start_date, end_date)
    	GROUP BY B.zip) bookingsIntermediate
    	ON L.zip = bookingsIntermediate.zip) AS fromBookings,
    	(SELECT L.zip,
        	COALESCE(driversIntermediate.revenue, 0) AS driverRevenue
    	FROM Locations L
    	LEFT JOIN
    	(SELECT E.zip,
        	COALESCE(SUM((H.todate - H.fromdate + 1) * 10), 0) AS revenue
    	FROM Hires H, Employees E
    	WHERE H.eid = E.eid AND
   		is_overlap(H.fromdate, H.todate, start_date, end_date)
    	GROUP BY E.zip) AS driversIntermediate
    	ON L.zip = driversIntermediate.zip) AS fromDrivers,
    	(SELECT L.zip,
        	COALESCE(carsIntermediate.revenue, 0) AS carRevenue
    	FROM Locations L
    	LEFT JOIN
    	(SELECT booking_zip AS zip,
        	SUM(distinctPlateCount * -100) AS revenue
    	FROM (
        	SELECT B.zip AS booking_zip,
            	D.plate,
            	COUNT(DISTINCT D.plate) AS distinctPlateCount
        	FROM CarDetails D
        	JOIN Assigns A ON D.plate = A.plate
        	JOIN Bookings B ON A.bid = B.bid
        	WHERE is_overlap(B.sdate, B.sdate + B.days - 1, start_date, end_date)
        	GROUP BY B.zip, D.plate
    	)
    	GROUP BY booking_zip) AS carsIntermediate
    	ON L.zip = carsIntermediate.zip) AS fromCars,
    	Locations Lmain
    	WHERE fromBookings.zip = fromDrivers.zip AND
        	fromBookings.zip = fromCars.zip AND
        	fromBookings.zip = Lmain.zip
    	ORDER BY fromBookings.bookingsRevenue + fromDrivers.driverRevenue + fromCars.carRevenue DESC;

	r RECORD;
	curr INT;
	count INT;
	dest INT;
	prev_revenue NUMERIC;
	n_tracker INT;
BEGIN
	curr := 1;
	n_tracker := 1;
	OPEN curs;
	LOOP
    	FETCH ABSOLUTE curr FROM curs INTO r;
    	EXIT WHEN NOT FOUND;
    	prev_revenue := r.revenue;
    	count := 0;
    	WHILE (FOUND AND r.revenue = prev_revenue AND prev_revenue = r.revenue) LOOP
        	count := count + 1;
        	FETCH ABSOLUTE curr + count FROM curs INTO r;
    	END LOOP;
    	dest := curr + count;
    	n_tracker := n_tracker + count;
    	IF (n_tracker - 1 <= n) THEN
        	WHILE (curr < dest) LOOP
            	FETCH ABSOLUTE curr FROM curs INTO r;
            	lname := r.lname;
            	revenue := r.revenue;
            	rank := dest - 1;
            	RETURN NEXT;
            	curr := curr + 1;
        	END LOOP;
    	END IF;
    	curr := dest;
	END LOOP;
	CLOSE curs;
END;
$$ LANGUAGE plpgsql;
