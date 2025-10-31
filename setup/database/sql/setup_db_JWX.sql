
CREATE DATABASE IF NOT EXISTS JWX
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
  
USE JWX;

-- ========================
-- Table: partner
-- ========================
CREATE TABLE partner (
    id INT AUTO_INCREMENT PRIMARY KEY,
    alias VARCHAR(255) NOT NULL
);

-- ========================
-- Table: budget_types
-- ========================
CREATE TABLE budget_types (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

-- ========================
-- Table: budgets
-- ========================
CREATE TABLE budgets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    budget_type_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    CONSTRAINT fk_budgets_budget_type
        FOREIGN KEY (budget_type_id)
        REFERENCES budget_types(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- ========================
-- Table: event_types
-- ========================
CREATE TABLE event_types (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

-- ========================
-- Table: event
-- ========================
CREATE TABLE event (
    id INT AUTO_INCREMENT PRIMARY KEY,
    partner_id INT NOT NULL,
    event_type_id INT NOT NULL,
    budget_id INT NOT NULL,
    amount DECIMAL(15,2) DEFAULT 0.00,
    price DECIMAL(15,2) DEFAULT 0.00,
    closed BOOLEAN DEFAULT FALSE,
    date_opened DATETIME DEFAULT CURRENT_TIMESTAMP,
    date_closed DATETIME NULL,
    ref_event_id INT NULL,
    deleted BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_event_partner
        FOREIGN KEY (partner_id)
        REFERENCES partner(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_event_event_type
        FOREIGN KEY (event_type_id)
        REFERENCES event_types(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_event_budget
        FOREIGN KEY (budget_id)
        REFERENCES budgets(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_event_ref_event
        FOREIGN KEY (ref_event_id)
        REFERENCES event(id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

-- ========================
-- Table: budget_performance
-- ========================
CREATE TABLE budget_performance (
    id INT AUTO_INCREMENT PRIMARY KEY,
    budget_id INT NOT NULL,
    event_id INT NOT NULL,
    volumen DECIMAL(15,2) DEFAULT 0.00,
    unitprice DECIMAL(15,2) DEFAULT 0.00,
    bilance DECIMAL(15,2) DEFAULT 0.00,
    date_created DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bp_budget
        FOREIGN KEY (budget_id)
        REFERENCES budgets(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_bp_event
        FOREIGN KEY (event_id)
        REFERENCES event(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
