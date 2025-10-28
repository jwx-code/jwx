USE `JWX`;
DELIMITER $$

/* -------------------------
   Table: partner
   ------------------------- */
DROP PROCEDURE IF EXISTS partner_create$$
CREATE PROCEDURE partner_create(
  IN p_alias VARCHAR(255)
)
BEGIN
  INSERT INTO `partner` (`alias`) VALUES (p_alias);
  SELECT LAST_INSERT_ID() AS id;
END$$

DROP PROCEDURE IF EXISTS partner_get$$
CREATE PROCEDURE partner_get(
  IN p_id INT
)
BEGIN
  SELECT * FROM `partner` WHERE `id` = p_id;
END$$

DROP PROCEDURE IF EXISTS partner_get_all$$
CREATE PROCEDURE partner_get_all()
BEGIN
  SELECT * FROM `partner` ORDER BY `id`;
END$$

DROP PROCEDURE IF EXISTS partner_update$$
CREATE PROCEDURE partner_update(
  IN p_id INT,
  IN p_alias VARCHAR(255)
)
BEGIN
  UPDATE `partner`
    SET `alias` = p_alias
    WHERE `id` = p_id;
  SELECT ROW_COUNT() AS affected;
END$$

DROP PROCEDURE IF EXISTS partner_delete$$
CREATE PROCEDURE partner_delete(
  IN p_id INT
)
BEGIN
  DELETE FROM `partner` WHERE `id` = p_id;
  SELECT ROW_COUNT() AS affected;
END$$

/* -------------------------
   Table: budget_types
   ------------------------- */
DROP PROCEDURE IF EXISTS budget_types_create$$
CREATE PROCEDURE budget_types_create(
  IN p_name VARCHAR(255)
)
BEGIN
  INSERT INTO `budget_types` (`name`) VALUES (p_name);
  SELECT LAST_INSERT_ID() AS id;
END$$

DROP PROCEDURE IF EXISTS budget_types_get$$
CREATE PROCEDURE budget_types_get(
  IN p_id INT
)
BEGIN
  SELECT * FROM `budget_types` WHERE `id` = p_id;
END$$

DROP PROCEDURE IF EXISTS budget_types_get_all$$
CREATE PROCEDURE budget_types_get_all()
BEGIN
  SELECT * FROM `budget_types` ORDER BY `id`;
END$$

DROP PROCEDURE IF EXISTS budget_types_update$$
CREATE PROCEDURE budget_types_update(
  IN p_id INT,
  IN p_name VARCHAR(255)
)
BEGIN
  UPDATE `budget_types`
    SET `name` = p_name
    WHERE `id` = p_id;
  SELECT ROW_COUNT() AS affected;
END$$

DROP PROCEDURE IF EXISTS budget_types_delete$$
CREATE PROCEDURE budget_types_delete(
  IN p_id INT
)
BEGIN
  DELETE FROM `budget_types` WHERE `id` = p_id;
  SELECT ROW_COUNT() AS affected;
END$$

/* -------------------------
   Table: budgets
   ------------------------- */
DROP PROCEDURE IF EXISTS budgets_create$$
CREATE PROCEDURE budgets_create(
  IN p_budget_type_id INT,
  IN p_name VARCHAR(255)
)
BEGIN
  INSERT INTO `budgets` (`budget_type_id`, `name`)
    VALUES (p_budget_type_id, p_name);
  SELECT LAST_INSERT_ID() AS id;
END$$

DROP PROCEDURE IF EXISTS budgets_get$$
CREATE PROCEDURE budgets_get(
  IN p_id INT
)
BEGIN
  SELECT b.*, bt.name AS budget_type_name
    FROM `budgets` b
    LEFT JOIN `budget_types` bt ON b.budget_type_id = bt.id
    WHERE b.id = p_id;
END$$

DROP PROCEDURE IF EXISTS budgets_get_all$$
CREATE PROCEDURE budgets_get_all()
BEGIN
  SELECT b.*, bt.name AS budget_type_name
    FROM `budgets` b
    LEFT JOIN `budget_types` bt ON b.budget_type_id = bt.id
    ORDER BY b.id;
END$$

DROP PROCEDURE IF EXISTS budgets_update$$
CREATE PROCEDURE budgets_update(
  IN p_id INT,
  IN p_budget_type_id INT,
  IN p_name VARCHAR(255)
)
BEGIN
  UPDATE `budgets`
    SET `budget_type_id` = p_budget_type_id,
        `name` = p_name
    WHERE `id` = p_id;
  SELECT ROW_COUNT() AS affected;
END$$

DROP PROCEDURE IF EXISTS budgets_delete$$
CREATE PROCEDURE budgets_delete(
  IN p_id INT
)
BEGIN
  DELETE FROM `budgets` WHERE `id` = p_id;
  SELECT ROW_COUNT() AS affected;
END$$

/* -------------------------
   Table: event_types
   ------------------------- */
DROP PROCEDURE IF EXISTS event_types_create$$
CREATE PROCEDURE event_types_create(
  IN p_name VARCHAR(255)
)
BEGIN
  INSERT INTO `event_types` (`name`) VALUES (p_name);
  SELECT LAST_INSERT_ID() AS id;
END$$

DROP PROCEDURE IF EXISTS event_types_get$$
CREATE PROCEDURE event_types_get(
  IN p_id INT
)
BEGIN
  SELECT * FROM `event_types` WHERE `id` = p_id;
END$$

DROP PROCEDURE IF EXISTS event_types_get_all$$
CREATE PROCEDURE event_types_get_all()
BEGIN
  SELECT * FROM `event_types` ORDER BY `id`;
END$$

DROP PROCEDURE IF EXISTS event_types_update$$
CREATE PROCEDURE event_types_update(
  IN p_id INT,
  IN p_name VARCHAR(255)
)
BEGIN
  UPDATE `event_types`
    SET `name` = p_name
    WHERE `id` = p_id;
  SELECT ROW_COUNT() AS affected;
END$$

DROP PROCEDURE IF EXISTS event_types_delete$$
CREATE PROCEDURE event_types_delete(
  IN p_id INT
)
BEGIN
  DELETE FROM `event_types` WHERE `id` = p_id;
  SELECT ROW_COUNT() AS affected;
END$$

/* -------------------------
   Table: event
   (soft delete über `deleted`-flag)
   ------------------------- */
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
  INSERT INTO `event`
    (`partner_id`, `event_type_id`, `budget_id`, `amount`, `price`, `closed`, `date_opened`, `date_closed`, `ref_event_id`, `deleted`)
  VALUES
    (p_partner_id, p_event_type_id, p_budget_id, COALESCE(p_amount, 0.00), COALESCE(p_price, 0.00), COALESCE(p_closed,0), p_date_opened, p_date_closed, p_ref_event_id, 0);
  SELECT LAST_INSERT_ID() AS id;
END$$

DROP PROCEDURE IF EXISTS event_get$$
CREATE PROCEDURE event_get(
  IN p_id INT
)
BEGIN
  SELECT e.*, p.alias AS partner_alias, et.name AS event_type_name, b.name AS budget_name
    FROM `event` e
    LEFT JOIN `partner` p ON e.partner_id = p.id
    LEFT JOIN `event_types` et ON e.event_type_id = et.id
    LEFT JOIN `budgets` b ON e.budget_id = b.id
    WHERE e.id = p_id;
END$$

DROP PROCEDURE IF EXISTS event_get_all$$
CREATE PROCEDURE event_get_all()
BEGIN
  SELECT e.*, p.alias AS partner_alias, et.name AS event_type_name, b.name AS budget_name
    FROM `event` e
    LEFT JOIN `partner` p ON e.partner_id = p.id
    LEFT JOIN `event_types` et ON e.event_type_id = et.id
    LEFT JOIN `budgets` b ON e.budget_id = b.id
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
  UPDATE `event`
    SET `partner_id` = p_partner_id,
        `event_type_id` = p_event_type_id,
        `budget_id` = p_budget_id,
        `amount` = p_amount,
        `price` = p_price,
        `closed` = p_closed,
        `date_opened` = p_date_opened,
        `date_closed` = p_date_closed,
        `ref_event_id` = p_ref_event_id,
        `deleted` = p_deleted
    WHERE `id` = p_id;
  SELECT ROW_COUNT() AS affected;
END$$

DROP PROCEDURE IF EXISTS event_delete$$
CREATE PROCEDURE event_delete(
  IN p_id INT
)
BEGIN
  -- Soft delete: set deleted = 1, date_closed optional
  UPDATE `event` SET `deleted` = 1 WHERE `id` = p_id;
  SELECT ROW_COUNT() AS affected;
END$$

/* -------------------------
   Table: budget_performance
   ------------------------- */
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
  INSERT INTO `budget_performance`
    (`budget_id`, `event_id`, `volumen`, `unitprice`, `bilance`, `date_created`)
  VALUES
    (p_budget_id, p_event_id, COALESCE(p_volumen,0.00), COALESCE(p_unitprice,0.00), COALESCE(p_bilance,0.00), p_date_created);
  SELECT LAST_INSERT_ID() AS id;
END$$

DROP PROCEDURE IF EXISTS budget_performance_get$$
CREATE PROCEDURE budget_performance_get(
  IN p_id INT
)
BEGIN
  SELECT bp.*, b.name AS budget_name, e.partner_id AS event_partner_id
    FROM `budget_performance` bp
    LEFT JOIN `budgets` b ON bp.budget_id = b.id
    LEFT JOIN `event` e ON bp.event_id = e.id
    WHERE bp.id = p_id;
END$$

DROP PROCEDURE IF EXISTS budget_performance_get_all$$
CREATE PROCEDURE budget_performance_get_all()
BEGIN
  SELECT bp.*, b.name AS budget_name, e.partner_id AS event_partner_id
    FROM `budget_performance` bp
    LEFT JOIN `budgets` b ON bp.budget_id = b.id
    LEFT JOIN `event` e ON bp.event_id = e.id
    ORDER BY bp.id;
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
  UPDATE `budget_performance`
    SET `budget_id` = p_budget_id,
        `event_id` = p_event_id,
        `volumen` = p_volumen,
        `unitprice` = p_unitprice,
        `bilance` = p_bilance,
        `date_created` = p_date_created
    WHERE `id` = p_id;
  SELECT ROW_COUNT() AS affected;
END$$

DROP PROCEDURE IF EXISTS budget_performance_delete$$
CREATE PROCEDURE budget_performance_delete(
  IN p_id INT
)
BEGIN
  DELETE FROM `budget_performance` WHERE `id` = p_id;
  SELECT ROW_COUNT() AS affected;
END$$

DELIMITER ;
