USE `JWX`;
DELIMITER $$

/* ============================
   Stored Procedures mit Validierung
============================ */

/* ---------------------------
   partner
--------------------------- */
DROP PROCEDURE IF EXISTS partner_create$$
CREATE PROCEDURE partner_create(IN p_alias VARCHAR(255))
BEGIN
    IF p_alias IS NULL OR TRIM(p_alias) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'partner_create: alias darf nicht leer sein';
    END IF;

    START TRANSACTION;
        INSERT INTO `partner` (`alias`) VALUES (p_alias);
        SELECT LAST_INSERT_ID() AS id;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS partner_get$$
CREATE PROCEDURE partner_get(IN p_id INT)
BEGIN
    SELECT * FROM `partner` WHERE id = p_id;
END$$

DROP PROCEDURE IF EXISTS partner_get_all$$
CREATE PROCEDURE partner_get_all()
BEGIN
    SELECT * FROM `partner` ORDER BY id;
END$$

DROP PROCEDURE IF EXISTS partner_update$$
CREATE PROCEDURE partner_update(IN p_id INT, IN p_alias VARCHAR(255))
BEGIN
    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'partner_update: ungültige id';
    END IF;
    IF p_alias IS NULL OR TRIM(p_alias) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'partner_update: alias darf nicht leer sein';
    END IF;

    START TRANSACTION;
        UPDATE `partner` SET alias = p_alias WHERE id = p_id;
        SELECT ROW_COUNT() AS affected;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS partner_delete$$
CREATE PROCEDURE partner_delete(IN p_id INT)
BEGIN
    DECLARE cnt INT DEFAULT 0;

    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'partner_delete: ungültige id';
    END IF;

    SELECT COUNT(*) INTO cnt FROM `event` WHERE partner_id = p_id AND deleted = 0;
    IF cnt > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'partner_delete: es existieren noch aktive events für diesen partner';
    END IF;

    START TRANSACTION;
        DELETE FROM `partner` WHERE id = p_id;
        SELECT ROW_COUNT() AS affected;
    COMMIT;
END$$

/* ---------------------------
   budget_types
--------------------------- */
DROP PROCEDURE IF EXISTS budget_types_create$$
CREATE PROCEDURE budget_types_create(IN p_name VARCHAR(255))
BEGIN
    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budget_types_create: name darf nicht leer sein';
    END IF;

    START TRANSACTION;
        INSERT INTO budget_types (name) VALUES (p_name);
        SELECT LAST_INSERT_ID() AS id;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS budget_types_get$$
CREATE PROCEDURE budget_types_get(IN p_id INT)
BEGIN
    SELECT * FROM budget_types WHERE id = p_id;
END$$

DROP PROCEDURE IF EXISTS budget_types_get_all$$
CREATE PROCEDURE budget_types_get_all()
BEGIN
    SELECT * FROM budget_types ORDER BY id;
END$$

DROP PROCEDURE IF EXISTS budget_types_update$$
CREATE PROCEDURE budget_types_update(IN p_id INT, IN p_name VARCHAR(255))
BEGIN
    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budget_types_update: ungültige id';
    END IF;
    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budget_types_update: name darf nicht leer sein';
    END IF;

    START TRANSACTION;
        UPDATE budget_types SET name = p_name WHERE id = p_id;
        SELECT ROW_COUNT() AS affected;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS budget_types_delete$$
CREATE PROCEDURE budget_types_delete(IN p_id INT)
BEGIN
    DECLARE cnt INT DEFAULT 0;

    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budget_types_delete: ungültige id';
    END IF;

    SELECT COUNT(*) INTO cnt FROM budgets WHERE budget_type_id = p_id;
    IF cnt > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budget_types_delete: dieser budget_type wird noch von budgets verwendet';
    END IF;

    START TRANSACTION;
        DELETE FROM budget_types WHERE id = p_id;
        SELECT ROW_COUNT() AS affected;
    COMMIT;
END$$

/* ---------------------------
   budgets
--------------------------- */
DROP PROCEDURE IF EXISTS budgets_create$$
CREATE PROCEDURE budgets_create(IN p_budget_type_id INT, IN p_name VARCHAR(255))
BEGIN
    DECLARE bt_cnt INT DEFAULT 0;

    IF p_budget_type_id IS NULL OR p_budget_type_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budgets_create: ungültige budget_type_id';
    END IF;
    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budgets_create: name darf nicht leer sein';
    END IF;

    SELECT COUNT(*) INTO bt_cnt FROM budget_types WHERE id = p_budget_type_id;
    IF bt_cnt = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budgets_create: budget_type_id existiert nicht';
    END IF;

    START TRANSACTION;
        INSERT INTO budgets (budget_type_id, name) VALUES (p_budget_type_id, p_name);
        SELECT LAST_INSERT_ID() AS id;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS budgets_get$$
CREATE PROCEDURE budgets_get(IN p_id INT)
BEGIN
    SELECT b.*, bt.name AS budget_type_name
    FROM budgets b
    LEFT JOIN budget_types bt ON b.budget_type_id = bt.id
    WHERE b.id = p_id;
END$$

DROP PROCEDURE IF EXISTS budgets_get_all$$
CREATE PROCEDURE budgets_get_all()
BEGIN
    SELECT b.*, bt.name AS budget_type_name
    FROM budgets b
    LEFT JOIN budget_types bt ON b.budget_type_id = bt.id
    ORDER BY b.id;
END$$

DROP PROCEDURE IF EXISTS budgets_update$$
CREATE PROCEDURE budgets_update(IN p_id INT, IN p_budget_type_id INT, IN p_name VARCHAR(255))
BEGIN
    DECLARE bt_cnt INT DEFAULT 0;

    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budgets_update: ungültige id';
    END IF;
    IF p_budget_type_id IS NULL OR p_budget_type_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budgets_update: ungültige budget_type_id';
    END IF;
    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budgets_update: name darf nicht leer sein';
    END IF;

    SELECT COUNT(*) INTO bt_cnt FROM budget_types WHERE id = p_budget_type_id;
    IF bt_cnt = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budgets_update: budget_type_id existiert nicht';
    END IF;

    START TRANSACTION;
        UPDATE budgets SET budget_type_id = p_budget_type_id, name = p_name WHERE id = p_id;
        SELECT ROW_COUNT() AS affected;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS budgets_delete$$
CREATE PROCEDURE budgets_delete(IN p_id INT)
BEGIN
    DECLARE cnt_event INT DEFAULT 0;
    DECLARE cnt_bp INT DEFAULT 0;

    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budgets_delete: ungültige id';
    END IF;

    SELECT COUNT(*) INTO cnt_event FROM `event` WHERE budget_id = p_id AND deleted = 0;
    IF cnt_event > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budgets_delete: vorhandene (aktive) events verweisen auf dieses budget';
    END IF;

    SELECT COUNT(*) INTO cnt_bp FROM budget_performance WHERE budget_id = p_id;
    IF cnt_bp > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budgets_delete: vorhandene budget_performance verweisen auf dieses budget';
    END IF;

    START TRANSACTION;
        DELETE FROM budgets WHERE id = p_id;
        SELECT ROW_COUNT() AS affected;
    COMMIT;
END$$

/* ---------------------------
   event_types
--------------------------- */
DROP PROCEDURE IF EXISTS event_types_create$$
CREATE PROCEDURE event_types_create(IN p_name VARCHAR(255))
BEGIN
    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_types_create: name darf nicht leer sein';
    END IF;

    START TRANSACTION;
        INSERT INTO event_types (name) VALUES (p_name);
        SELECT LAST_INSERT_ID() AS id;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS event_types_get$$
CREATE PROCEDURE event_types_get(IN p_id INT)
BEGIN
    SELECT * FROM event_types WHERE id = p_id;
END$$

DROP PROCEDURE IF EXISTS event_types_get_all$$
CREATE PROCEDURE event_types_get_all()
BEGIN
    SELECT * FROM event_types ORDER BY id;
END$$

DROP PROCEDURE IF EXISTS event_types_update$$
CREATE PROCEDURE event_types_update(IN p_id INT, IN p_name VARCHAR(255))
BEGIN
    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_types_update: ungültige id';
    END IF;
    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_types_update: name darf nicht leer sein';
    END IF;

    START TRANSACTION;
        UPDATE event_types SET name = p_name WHERE id = p_id;
        SELECT ROW_COUNT() AS affected;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS event_types_delete$$
CREATE PROCEDURE event_types_delete(IN p_id INT)
BEGIN
    DECLARE cnt INT DEFAULT 0;

    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_types_delete: ungültige id';
    END IF;

    SELECT COUNT(*) INTO cnt FROM `event` WHERE event_type_id = p_id AND deleted = 0;
    IF cnt > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_types_delete: vorhandene (aktive) events verweisen auf diesen event_type';
    END IF;

    START TRANSACTION;
        DELETE FROM event_types WHERE id = p_id;
        SELECT ROW_COUNT() AS affected;
    COMMIT;
END$$

/* ---------------------------
   event
--------------------------- */
DROP PROCEDURE IF EXISTS event_create$$
CREATE PROCEDURE event_create(
    IN p_partner_id INT,
    IN p_event_type_id INT,
    IN p_budget_id INT,
    IN p_amount DECIMAL(15,2),
    IN p_price DECIMAL(15,2),
    IN p_closed TINYINT(1),
    IN p_date_opened DATETIME,
    IN p_date_closed DATETIME,
    IN p_ref_event_id INT
)
BEGIN
    DECLARE cnt_partner INT DEFAULT 0;
    DECLARE cnt_et INT DEFAULT 0;
    DECLARE cnt_b INT DEFAULT 0;
    DECLARE cnt_ref INT DEFAULT 0;

    IF p_partner_id IS NULL OR p_partner_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_create: ungültige partner_id';
    END IF;
    IF p_event_type_id IS NULL OR p_event_type_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_create: ungültige event_type_id';
    END IF;
    IF p_budget_id IS NULL OR p_budget_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_create: ungültige budget_id';
    END IF;

    SELECT COUNT(*) INTO cnt_partner FROM partner WHERE id = p_partner_id;
    IF cnt_partner = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_create: partner_id existiert nicht';
    END IF;

    SELECT COUNT(*) INTO cnt_et FROM event_types WHERE id = p_event_type_id;
    IF cnt_et = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_create: event_type_id existiert nicht';
    END IF;

    SELECT COUNT(*) INTO cnt_b FROM budgets WHERE id = p_budget_id;
    IF cnt_b = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_create: budget_id existiert nicht';
    END IF;

    IF p_ref_event_id IS NOT NULL THEN
        SELECT COUNT(*) INTO cnt_ref FROM `event` WHERE id = p_ref_event_id;
        IF cnt_ref = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_create: ref_event_id existiert nicht';
        END IF;
    END IF;

    IF p_amount IS NULL THEN SET p_amount = 0.00; END IF;
    IF p_price IS NULL THEN SET p_price = 0.00; END IF;
    IF p_closed IS NULL THEN SET p_closed = 0; END IF;

    START TRANSACTION;
        INSERT INTO `event` (
            partner_id, event_type_id, budget_id, amount, price, closed, date_opened, date_closed, ref_event_id, deleted
        ) VALUES (
            p_partner_id, p_event_type_id, p_budget_id, p_amount, p_price, p_closed, p_date_opened, p_date_closed, p_ref_event_id, 0
        );
        SELECT LAST_INSERT_ID() AS id;
    COMMIT;
END$$

DELIMITER $$

DROP PROCEDURE IF EXISTS event_get$$
CREATE PROCEDURE event_get(IN p_id INT)
BEGIN
    SELECT e.*, p.alias AS partner_alias, et.name AS event_type_name, b.name AS budget_name
    FROM `event` e
    LEFT JOIN partner p ON e.partner_id = p.id
    LEFT JOIN event_types et ON e.event_type_id = et.id
    LEFT JOIN budgets b ON e.budget_id = b.id
    WHERE e.id = p_id;
END$$

DROP PROCEDURE IF EXISTS event_get_all$$
CREATE PROCEDURE event_get_all()
BEGIN
    SELECT e.*, p.alias AS partner_alias, et.name AS event_type_name, b.name AS budget_name
    FROM `event` e
    LEFT JOIN partner p ON e.partner_id = p.id
    LEFT JOIN event_types et ON e.event_type_id = et.id
    LEFT JOIN budgets b ON e.budget_id = b.id
    ORDER BY e.id;
END$$

DROP PROCEDURE IF EXISTS event_update$$
CREATE PROCEDURE event_update(
    IN p_id INT,
    IN p_partner_id INT,
    IN p_event_type_id INT,
    IN p_budget_id INT,
    IN p_amount DECIMAL(15,2),
    IN p_price DECIMAL(15,2),
    IN p_closed TINYINT(1),
    IN p_date_opened DATETIME,
    IN p_date_closed DATETIME,
    IN p_ref_event_id INT,
    IN p_deleted TINYINT(1)
)
BEGIN
    DECLARE cnt_event INT DEFAULT 0;
    DECLARE cnt_partner INT DEFAULT 0;
    DECLARE cnt_et INT DEFAULT 0;
    DECLARE cnt_b INT DEFAULT 0;
    DECLARE cnt_ref INT DEFAULT 0;

    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_update: ungültige id';
    END IF;

    SELECT COUNT(*) INTO cnt_event FROM `event` WHERE id = p_id;
    IF cnt_event = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_update: event existiert nicht';
    END IF;

    IF p_partner_id IS NOT NULL THEN
        SELECT COUNT(*) INTO cnt_partner FROM partner WHERE id = p_partner_id;
        IF cnt_partner = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_update: partner_id existiert nicht';
        END IF;
    END IF;

    IF p_event_type_id IS NOT NULL THEN
        SELECT COUNT(*) INTO cnt_et FROM event_types WHERE id = p_event_type_id;
        IF cnt_et = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_update: event_type_id existiert nicht';
        END IF;
    END IF;

    IF p_budget_id IS NOT NULL THEN
        SELECT COUNT(*) INTO cnt_b FROM budgets WHERE id = p_budget_id;
        IF cnt_b = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_update: budget_id existiert nicht';
        END IF;
    END IF;

    IF p_ref_event_id IS NOT NULL THEN
        SELECT COUNT(*) INTO cnt_ref FROM `event` WHERE id = p_ref_event_id;
        IF cnt_ref = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_update: ref_event_id existiert nicht';
        END IF;
    END IF;

    START TRANSACTION;
        UPDATE `event` SET
            partner_id = COALESCE(p_partner_id, partner_id),
            event_type_id = COALESCE(p_event_type_id, event_type_id),
            budget_id = COALESCE(p_budget_id, budget_id),
            amount = COALESCE(p_amount, amount),
            price = COALESCE(p_price, price),
            closed = COALESCE(p_closed, closed),
            date_opened = COALESCE(p_date_opened, date_opened),
            date_closed = COALESCE(p_date_closed, date_closed),
            ref_event_id = COALESCE(p_ref_event_id, ref_event_id),
            deleted = COALESCE(p_deleted, deleted)
        WHERE id = p_id;
        SELECT ROW_COUNT() AS affected;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS event_delete$$
CREATE PROCEDURE event_delete(IN p_id INT)
BEGIN
    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_delete: ungültige id';
    END IF;

    START TRANSACTION;
        UPDATE `event` SET deleted = 1 WHERE id = p_id;
        SELECT ROW_COUNT() AS affected;
    COMMIT;
END$$

/* ---------------------------
   budget_performance
--------------------------- */
DROP PROCEDURE IF EXISTS budget_performance_create$$
CREATE PROCEDURE budget_performance_create(
    IN p_budget_id INT,
    IN p_event_id INT,
    IN p_volumen DECIMAL(15,2),
    IN p_unitprice DECIMAL(15,2),
    IN p_bilance DECIMAL(15,2),
    IN p_date_created DATETIME
)
BEGIN
    DECLARE cnt_b INT DEFAULT 0;
    DECLARE cnt_e INT DEFAULT 0;

    IF p_budget_id IS NULL OR p_budget_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budget_performance_create: ungültige budget_id';
    END IF;

    IF p_event_id IS NULL OR p_event_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budget_performance_create: ungültige event_id';
    END IF;

    SELECT COUNT(*) INTO cnt_b FROM budgets WHERE id = p_budget_id;
    IF cnt_b = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budget_performance_create: budget_id existiert nicht';
    END IF;

    SELECT COUNT(*) INTO cnt_e FROM `event` WHERE id = p_event_id;
    IF cnt_e = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budget_performance_create: event_id existiert nicht';
    END IF;

    IF p_volumen IS NULL THEN SET p_volumen = 0.00; END IF;
    IF p_unitprice IS NULL THEN SET p_unitprice = 0.00; END IF;
    IF p_bilance IS NULL THEN SET p_bilance = 0.00; END IF;

    START TRANSACTION;
        INSERT INTO budget_performance (budget_id, event_id, volumen, unitprice, bilance, date_created)
        VALUES (p_budget_id, p_event_id, p_volumen, p_unitprice, p_bilance, p_date_created);
        SELECT LAST_INSERT_ID() AS id;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS budget_performance_update$$
CREATE PROCEDURE budget_performance_update(
    IN p_id INT,
    IN p_budget_id INT,
    IN p_event_id INT,
    IN p_volumen DECIMAL(15,2),
    IN p_unitprice DECIMAL(15,2),
    IN p_bilance DECIMAL(15,2),
    IN p_date_created DATETIME
)
BEGIN
    DECLARE cnt_bp INT DEFAULT 0;
    DECLARE cnt_b INT DEFAULT 0;
    DECLARE cnt_e INT DEFAULT 0;

    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budget_performance_update: ungültige id';
    END IF;

    SELECT COUNT(*) INTO cnt_bp FROM budget_performance WHERE id = p_id;
    IF cnt_bp = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budget_performance_update: record existiert nicht';
    END IF;

    IF p_budget_id IS NOT NULL THEN
        SELECT COUNT(*) INTO cnt_b FROM budgets WHERE id = p_budget_id;
        IF cnt_b = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budget_performance_update: budget_id existiert nicht';
        END IF;
    END IF;

    IF p_event_id IS NOT NULL THEN
        SELECT COUNT(*) INTO cnt_e FROM `event` WHERE id = p_event_id;
        IF cnt_e = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budget_performance_update: event_id existiert nicht';
        END IF;
    END IF;

    START TRANSACTION;
        UPDATE budget_performance SET
            budget_id = COALESCE(p_budget_id, budget_id),
            event_id = COALESCE(p_event_id, event_id),
            volumen = COALESCE(p_volumen, volumen),
            unitprice = COALESCE(p_unitprice, unitprice),
            bilance = COALESCE(p_bilance, bilance),
            date_created = COALESCE(p_date_created, date_created)
        WHERE id = p_id;
        SELECT ROW_COUNT() AS affected;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS budget_performance_delete$$
CREATE PROCEDURE budget_performance_delete(IN p_id INT)
BEGIN
    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'budget_performance_delete: ungültige id';
    END IF;

    START TRANSACTION;
        DELETE FROM budget_performance WHERE id = p_id;
        SELECT ROW_COUNT() AS affected;
    COMMIT;
END$$

DELIMITER ;
