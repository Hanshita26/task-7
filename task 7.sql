DROP PROCEDURE IF EXISTS SCD0_ProcessCustomer;
DROP PROCEDURE IF EXISTS SCD1_ProcessCustomer;
DROP PROCEDURE IF EXISTS SCD2_ProcessCustomer;
DROP PROCEDURE IF EXISTS SCD3_ProcessCustomer;
DROP PROCEDURE IF EXISTS SCD4_ProcessCustomer;
DROP PROCEDURE IF EXISTS SCD6_ProcessCustomer;

DROP TABLE IF EXISTS Customers;
DROP TABLE IF EXISTS Customers_Current;
DROP TABLE IF EXISTS Customers_History;

CREATE TABLE Customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    CustomerID VARCHAR(50) UNIQUE NOT NULL,
    Name VARCHAR(255),
    Address VARCHAR(255),
    City VARCHAR(100),
    State VARCHAR(100),
    ZipCode VARCHAR(20),
    PhoneNumber VARCHAR(50),
    Email VARCHAR(255),
    Status VARCHAR(50),
    PreviousCity VARCHAR(100),
    EffectiveDate DATETIME,
    EndDate DATETIME,
    IsCurrent BOOLEAN
);

CREATE TABLE Customers_Current (
    CustomerID VARCHAR(50) PRIMARY KEY,
    Name VARCHAR(255),
    Address VARCHAR(255),
    City VARCHAR(100),
    PhoneNumber VARCHAR(50),
    Email VARCHAR(255),
    Status VARCHAR(50)
);

CREATE TABLE Customers_History (
    HistoryID INT AUTO_INCREMENT PRIMARY KEY,
    CustomerID VARCHAR(50) NOT NULL,
    Name VARCHAR(255),
    Address VARCHAR(255),
    City VARCHAR(100),
    PhoneNumber VARCHAR(50),
    Email VARCHAR(255),
    Status VARCHAR(50),
    ChangeTimestamp DATETIME NOT NULL,
    ChangeType VARCHAR(50)
);

DELIMITER //

CREATE PROCEDURE SCD0_ProcessCustomer (
    IN p_CustomerID VARCHAR(50),
    IN p_Name VARCHAR(255),
    IN p_InitialRegistrationDate DATETIME
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Customers WHERE CustomerID = p_CustomerID) THEN
        INSERT INTO Customers (CustomerID, Name, EffectiveDate, IsCurrent)
        VALUES (p_CustomerID, p_Name, p_InitialRegistrationDate, TRUE);
    ELSE
        SELECT 'Customer with this ID already exists. Fixed attributes not updated.' AS Message;
    END IF;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE SCD1_ProcessCustomer (
    IN p_CustomerID VARCHAR(50),
    IN p_Name VARCHAR(255),
    IN p_PhoneNumber VARCHAR(50),
    IN p_Email VARCHAR(255)
)
BEGIN
    IF EXISTS (SELECT 1 FROM Customers WHERE CustomerID = p_CustomerID) THEN
        UPDATE Customers
        SET
            Name = p_Name,
            PhoneNumber = p_PhoneNumber,
            Email = p_Email
        WHERE CustomerID = p_CustomerID;
    ELSE
        INSERT INTO Customers (CustomerID, Name, PhoneNumber, Email, EffectiveDate, IsCurrent)
        VALUES (p_CustomerID, p_Name, p_PhoneNumber, p_Email, NOW(), TRUE);
    END IF;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE SCD2_ProcessCustomer (
    IN p_CustomerID VARCHAR(50),
    IN p_Name VARCHAR(255),
    IN p_Address VARCHAR(255),
    IN p_City VARCHAR(100),
    IN p_State VARCHAR(100),
    IN p_ZipCode VARCHAR(20)
)
BEGIN
    DECLARE v_CurrentId INT;
    DECLARE v_OldAddress VARCHAR(255);
    DECLARE v_OldCity VARCHAR(100);
    DECLARE v_OldState VARCHAR(100);
    DECLARE v_OldZipCode VARCHAR(20);

    SELECT id, Address, City, State, ZipCode
    INTO v_CurrentId, v_OldAddress, v_OldCity, v_OldState, v_OldZipCode
    FROM Customers
    WHERE CustomerID = p_CustomerID AND IsCurrent = TRUE;

    IF v_CurrentId IS NULL THEN
        INSERT INTO Customers (CustomerID, Name, Address, City, State, ZipCode, EffectiveDate, IsCurrent)
        VALUES (p_CustomerID, p_Name, p_Address, p_City, p_State, p_ZipCode, NOW(), TRUE);
    ELSE
        IF v_OldAddress <> p_Address OR v_OldCity <> p_City OR v_OldState <> p_State OR v_OldZipCode <> p_ZipCode THEN
            UPDATE Customers
            SET EndDate = NOW(), IsCurrent = FALSE
            WHERE id = v_CurrentId;

            INSERT INTO Customers (CustomerID, Name, Address, City, State, ZipCode, EffectiveDate, IsCurrent)
            VALUES (p_CustomerID, p_Name, p_Address, p_City, p_State, p_ZipCode, NOW(), TRUE);
        ELSE
            UPDATE Customers
            SET Name = p_Name
            WHERE id = v_CurrentId;
        END IF;
    END IF;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE SCD3_ProcessCustomer (
    IN p_CustomerID VARCHAR(50),
    IN p_Name VARCHAR(255),
    IN p_CurrentCity VARCHAR(100)
)
BEGIN
    DECLARE v_OldCity VARCHAR(100);

    SELECT City INTO v_OldCity
    FROM Customers
    WHERE CustomerID = p_CustomerID AND IsCurrent = TRUE;

    IF v_OldCity IS NULL THEN
        INSERT INTO Customers (CustomerID, Name, City, PreviousCity, EffectiveDate, IsCurrent)
        VALUES (p_CustomerID, p_Name, p_CurrentCity, NULL, NOW(), TRUE);
    ELSE
        IF v_OldCity <> p_CurrentCity THEN
            UPDATE Customers
            SET
                Name = p_Name,
                PreviousCity = v_OldCity,
                City = p_CurrentCity
            WHERE CustomerID = p_CustomerID AND IsCurrent = TRUE;
        ELSE
            UPDATE Customers
            SET Name = p_Name
            WHERE CustomerID = p_CustomerID AND IsCurrent = TRUE;
        END IF;
    END IF;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE SCD4_ProcessCustomer (
    IN p_CustomerID VARCHAR(50),
    IN p_Name VARCHAR(255),
    IN p_Address VARCHAR(255),
    IN p_City VARCHAR(100),
    IN p_PhoneNumber VARCHAR(50),
    IN p_Email VARCHAR(255),
    IN p_Status VARCHAR(50)
)
BEGIN
    DECLARE v_OldName VARCHAR(255);
    DECLARE v_OldAddress VARCHAR(255);
    DECLARE v_OldCity VARCHAR(100);
    DECLARE v_OldPhoneNumber VARCHAR(50);
    DECLARE v_OldEmail VARCHAR(255);
    DECLARE v_OldStatus VARCHAR(50);

    SELECT Name, Address, City, PhoneNumber, Email, Status
    INTO v_OldName, v_OldAddress, v_OldCity, v_OldPhoneNumber, v_OldEmail, v_OldStatus
    FROM Customers_Current
    WHERE CustomerID = p_CustomerID;

    IF v_OldName IS NULL THEN
        INSERT INTO Customers_Current (CustomerID, Name, Address, City, PhoneNumber, Email, Status)
        VALUES (p_CustomerID, p_Name, p_Address, p_City, p_PhoneNumber, p_Email, p_Status);

        INSERT INTO Customers_History (CustomerID, Name, Address, City, PhoneNumber, Email, Status, ChangeTimestamp, ChangeType)
        VALUES (p_CustomerID, p_Name, p_Address, p_City, p_PhoneNumber, p_Email, p_Status, NOW(), 'INSERT');
    ELSE
        IF v_OldName <> p_Name OR v_OldAddress <> p_Address OR v_OldCity <> p_City OR
           v_OldPhoneNumber <> p_PhoneNumber OR v_OldEmail <> p_Email OR v_OldStatus <> p_Status THEN

            UPDATE Customers_Current
            SET
                Name = p_Name,
                Address = p_Address,
                City = p_City,
                PhoneNumber = p_PhoneNumber,
                Email = p_Email,
                Status = p_Status
            WHERE CustomerID = p_CustomerID;

            INSERT INTO Customers_History (CustomerID, Name, Address, City, PhoneNumber, Email, Status, ChangeTimestamp, ChangeType)
            VALUES (p_CustomerID, p_Name, p_Address, p_City, p_PhoneNumber, p_Email, p_Status, NOW(), 'UPDATE');
        END IF;
    END IF;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE SCD6_ProcessCustomer (
    IN p_CustomerID VARCHAR(50),
    IN p_Name VARCHAR(255),
    IN p_Address VARCHAR(255),
    IN p_City VARCHAR(100),
    IN p_PhoneNumber VARCHAR(50)
)
BEGIN
    DECLARE v_CurrentId INT;
    DECLARE v_OldName VARCHAR(255);
    DECLARE v_OldAddress VARCHAR(255);
    DECLARE v_OldCity VARCHAR(100);
    DECLARE v_OldPhoneNumber VARCHAR(50);
    DECLARE v_OldPreviousCity VARCHAR(100);

    SELECT id, Name, Address, City, PhoneNumber, PreviousCity
    INTO v_CurrentId, v_OldName, v_OldAddress, v_OldCity, v_OldPhoneNumber, v_OldPreviousCity
    FROM Customers
    WHERE CustomerID = p_CustomerID AND IsCurrent = TRUE;

    IF v_CurrentId IS NULL THEN
        INSERT INTO Customers (CustomerID, Name, Address, City, PreviousCity, PhoneNumber, EffectiveDate, IsCurrent)
        VALUES (p_CustomerID, p_Name, p_Address, p_City, NULL, p_PhoneNumber, NOW(), TRUE);
    ELSE
        IF v_OldAddress <> p_Address THEN
            UPDATE Customers
            SET EndDate = NOW(), IsCurrent = FALSE
            WHERE id = v_CurrentId;

            INSERT INTO Customers (CustomerID, Name, Address, City, PreviousCity, PhoneNumber, EffectiveDate, IsCurrent)
            VALUES (
                p_CustomerID,
                p_Name,
                p_Address,
                p_City,
                v_OldCity,
                p_PhoneNumber,
                NOW(),
                TRUE
            );
        ELSE
            IF v_OldName <> p_Name OR v_OldPhoneNumber <> p_PhoneNumber OR v_OldCity <> p_City THEN
                UPDATE Customers
                SET
                    Name = p_Name,
                    PhoneNumber = p_PhoneNumber,
                    PreviousCity = CASE WHEN v_OldCity <> p_City THEN v_OldCity ELSE PreviousCity END,
                    City = p_City
                WHERE id = v_CurrentId;
            END IF;
        END IF;
    END IF;
END //

DELIMITER ;

TRUNCATE TABLE Customers;
TRUNCATE TABLE Customers_Current;
TRUNCATE TABLE Customers_History;

CALL SCD0_ProcessCustomer('CUST001', 'Alice Smith', '2023-01-15 10:00:00');
CALL SCD0_ProcessCustomer('CUST002', 'Bob Johnson', '2023-02-20 11:30:00');
CALL SCD0_ProcessCustomer('CUST001', 'Alicia Smith', '2023-01-15 10:00:00');

CALL SCD1_ProcessCustomer('CUST003', 'Charlie Brown', '555-1111', 'charlie@example.com');
CALL SCD1_ProcessCustomer('CUST003', 'Charlie Brown', '555-2222', 'charlie.b@example.com');

CALL SCD2_ProcessCustomer('CUST004', 'Diana Prince', '123 Main St', 'Metropolis', 'NY', '10001');
CALL SCD2_ProcessCustomer('CUST004', 'Diana Prince', '456 Oak Ave', 'Gotham', 'NJ', '07001');
CALL SCD2_ProcessCustomer('CUST004', 'Diana Wayne', '456 Oak Ave', 'Gotham', 'NJ', '07001');

CALL SCD3_ProcessCustomer('CUST005', 'Eve Adams', 'Springfield');
CALL SCD3_ProcessCustomer('CUST005', 'Eve Adams', 'Shelbyville');
CALL SCD3_ProcessCustomer('CUST005', 'Eve Adams', 'Capital City');

CALL SCD4_ProcessCustomer('CUST006', 'Frank Green', '789 Pine St', 'Smallville', '555-3333', 'frank@example.com', 'Active');
CALL SCD4_ProcessCustomer('CUST006', 'Frank Green', '101 Elm St', 'Smallville', '555-3333', 'frank@example.com', 'Inactive');

CALL SCD6_ProcessCustomer('CUST007', 'Grace Hopper', '100 Tech Way', 'Innovation City', '555-4444');
CALL SCD6_ProcessCustomer('CUST007', 'Grace Hopper', '100 Tech Way', 'Data Town', '555-5555');
CALL SCD6_ProcessCustomer('CUST007', 'Grace Hopper', '200 Code Blvd', 'Algorithm Alley', '555-6666');
