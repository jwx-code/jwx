/* -----------------------------------------------------------
   1) Log-Schema + zentrale Audit-Tabelle
   ----------------------------------------------------------- */

CREATE DATABASE IF NOT EXISTS JWX_LOG
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Zentrale Audit-Tabelle (DML-Events)
CREATE TABLE IF NOT EXISTS JWX_LOG.audit_event (
  id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  event_time     TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  db_name        VARCHAR(64)  NOT NULL,
  table_name     VARCHAR(64)  NOT NULL,
  action         ENUM('INSERT','UPDATE','DELETE') NOT NULL,
  pk_json        JSON NULL,          -- Primärschlüsselwerte (JSON)
  before_json    JSON NULL,          -- kompletter Datensatz VORHER (UPDATE/DELETE)
  after_json     JSON NULL,          -- kompletter Datensatz NACHHER (INSERT/UPDATE)
  actor          VARCHAR(100) NOT NULL, -- CURRENT_USER()
  host           VARCHAR(255) NOT NULL, -- SUBSTRING_INDEX(USER(),'@',-1)
  connection_id  BIGINT UNSIGNED NOT NULL, -- CONNECTION_ID()
  comment        TEXT NULL,
  INDEX idx_time (event_time),
  INDEX idx_tbl  (db_name, table_name, event_time),
  INDEX idx_conn (connection_id)
) ENGINE=InnoDB;

-- (Optional) Ausschluss-Liste: Tabellen, die NICHT auditiert werden sollen
CREATE TABLE IF NOT EXISTS JWX_LOG.audit_skip (
  table_schema VARCHAR(64) NOT NULL,
  table_name   VARCHAR(64) NOT NULL,
  PRIMARY KEY (table_schema, table_name)
) ENGINE=InnoDB;


/* -----------------------------------------------------------
   2) Event-Scheduler aktivieren (sofern Berechtigung vorhanden)
   ----------------------------------------------------------- */

-- Für die laufende Instanz:
SET GLOBAL event_scheduler = ON;

-- Persistiert über Neustart (falls erlaubt):
-- SET PERSIST event_scheduler = ON;


/* -----------------------------------------------------------
   3) Prozedur: Trigger für EINE Tabelle erzeugen/erneuern
   ----------------------------------------------------------- */

DELIMITER $$

CREATE PROCEDURE JWX_LOG.sp_enable_audit_for_table(
  IN p_db    VARCHAR(64),
  IN p_table VARCHAR(64)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_json_new LONGTEXT;
  DECLARE v_json_old LONGTEXT;
  DECLARE v_json_pk_new LONGTEXT;
  DECLARE v_json_pk_old LONGTEXT;

  DECLARE v_qdb   VARCHAR(70);    -- z. B. `JWX`
  DECLARE v_qtab  VARCHAR(70);    -- z. B. `users`
  DECLARE v_trg_ai VARCHAR(200);  -- z. B. JWX.users_AI_AUDIT (ohne Backticks im Triggernamen)
  DECLARE v_trg_au VARCHAR(200);
  DECLARE v_trg_ad VARCHAR(200);

  /* Größere GROUP_CONCAT-Länge, damit JSON_OBJECT(...) nicht abgeschnitten wird */
  SET SESSION group_concat_max_len = 1048576;

  /* Identifiers sicher quoten für DB/Tabelle (für die ON-Klausel) */
  SET v_qdb  = CONCAT('`', REPLACE(p_db,  '`','``'), '`');
  SET v_qtab = CONCAT('`', REPLACE(p_table,'`','``'), '`');

  /* Trigger-Namen (schema.qualifiziert, aber OHNE Backticks im Triggernamen selbst) */
  SET v_trg_ai = CONCAT(p_db, '.', p_table, '_AI_AUDIT');
  SET v_trg_au = CONCAT(p_db, '.', p_table, '_AU_AUDIT');
  SET v_trg_ad = CONCAT(p_db, '.', p_table, '_AD_AUDIT');

  /* JSON_OBJECT für NEW.* und OLD.* dynamisch bauen */
  SELECT CONCAT(
           'JSON_OBJECT(',
           GROUP_CONCAT(CONCAT('''', COLUMN_NAME, '''', ', NEW.`', REPLACE(COLUMN_NAME,'`','``'), '`')
                        ORDER BY ORDINAL_POSITION SEPARATOR ', '),
           ')'
         )
    INTO v_json_new
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = p_db AND TABLE_NAME = p_table;

  SELECT CONCAT(
           'JSON_OBJECT(',
           GROUP_CONCAT(CONCAT('''', COLUMN_NAME, '''', ', OLD.`', REPLACE(COLUMN_NAME,'`','``'), '`')
                        ORDER BY ORDINAL_POSITION SEPARATOR ', '),
           ')'
         )
    INTO v_json_old
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = p_db AND TABLE_NAME = p_table;

  /* JSON nur für PRIMARY KEY (kann NULL sein, falls kein PK) */
  SELECT CONCAT(
           'JSON_OBJECT(',
           GROUP_CONCAT(CONCAT('''', s.COLUMN_NAME, '''', ', NEW.`', REPLACE(s.COLUMN_NAME,'`','``'), '`')
                        ORDER BY s.SEQ_IN_INDEX SEPARATOR ', '),
           ')'
         )
    INTO v_json_pk_new
  FROM INFORMATION_SCHEMA.STATISTICS s
  WHERE s.TABLE_SCHEMA = p_db AND s.TABLE_NAME = p_table AND s.INDEX_NAME = 'PRIMARY';

  SELECT CONCAT(
           'JSON_OBJECT(',
           GROUP_CONCAT(CONCAT('''', s.COLUMN_NAME, '''', ', OLD.`', REPLACE(s.COLUMN_NAME,'`','``'), '`')
                        ORDER BY s.SEQ_IN_INDEX SEPARATOR ', '),
           ')'
         )
    INTO v_json_pk_old
  FROM INFORMATION_SCHEMA.STATISTICS s
  WHERE s.TABLE_SCHEMA = p_db AND s.TABLE_NAME = p_table AND s.INDEX_NAME = 'PRIMARY';

  /* Vorhandene Trigger sauber entfernen */
  SET @sql := CONCAT('DROP TRIGGER IF EXISTS ', v_trg_ai);
  PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

  SET @sql := CONCAT('DROP TRIGGER IF EXISTS ', v_trg_au);
  PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

  SET @sql := CONCAT('DROP TRIGGER IF EXISTS ', v_trg_ad);
  PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

  /* AFTER INSERT */
  SET @sql := CONCAT(
    'CREATE TRIGGER ', v_trg_ai, ' AFTER INSERT ON ', v_qdb, '.', v_qtab, '
     FOR EACH ROW
     BEGIN
       /* Ausschlussliste: wenn Tabelle geskippt werden soll, nichts tun */
       IF NOT EXISTS (
         SELECT 1 FROM JWX_LOG.audit_skip s
         WHERE s.table_schema = ', QUOTE(p_db), ' AND s.table_name = ', QUOTE(p_table), '
       ) THEN
         INSERT INTO JWX_LOG.audit_event
           (db_name, table_name, action, pk_json, before_json, after_json, actor, host, connection_id)
         VALUES
           (', QUOTE(p_db), ', ', QUOTE(p_table), ', ''INSERT'',
            ', IFNULL(v_json_pk_new, 'NULL'), ',
            NULL,
            ', v_json_new, ',
            CURRENT_USER(),
            SUBSTRING_INDEX(USER(), ''@'', -1),
            CONNECTION_ID());
       END IF;
     END'
  );
  PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

  /* AFTER UPDATE */
  SET @sql := CONCAT(
    'CREATE TRIGGER ', v_trg_au, ' AFTER UPDATE ON ', v_qdb, '.', v_qtab, '
     FOR EACH ROW
     BEGIN
       IF NOT EXISTS (
         SELECT 1 FROM JWX_LOG.audit_skip s
         WHERE s.table_schema = ', QUOTE(p_db), ' AND s.table_name = ', QUOTE(p_table), '
       ) THEN
         INSERT INTO JWX_LOG.audit_event
           (db_name, table_name, action, pk_json, before_json, after_json, actor, host, connection_id)
         VALUES
           (', QUOTE(p_db), ', ', QUOTE(p_table), ', ''UPDATE'',
            ', IFNULL(v_json_pk_new, 'NULL'), ',
            ', v_json_old, ',
            ', v_json_new, ',
            CURRENT_USER(),
            SUBSTRING_INDEX(USER(), ''@'', -1),
            CONNECTION_ID());
       END IF;
     END'
  );
  PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

  /* AFTER DELETE */
  SET @sql := CONCAT(
    'CREATE TRIGGER ', v_trg_ad, ' AFTER DELETE ON ', v_qdb, '.', v_qtab, '
     FOR EACH ROW
     BEGIN
       IF NOT EXISTS (
         SELECT 1 FROM JWX_LOG.audit_skip s
         WHERE s.table_schema = ', QUOTE(p_db), ' AND s.table_name = ', QUOTE(p_table), '
       ) THEN
         INSERT INTO JWX_LOG.audit_event
           (db_name, table_name, action, pk_json, before_json, after_json, actor, host, connection_id)
         VALUES
           (', QUOTE(p_db), ', ', QUOTE(p_table), ', ''DELETE'',
            ', IFNULL(v_json_pk_old, 'NULL'), ',
            ', v_json_old, ',
            NULL,
            CURRENT_USER(),
            SUBSTRING_INDEX(USER(), ''@'', -1),
            CONNECTION_ID());
       END IF;
     END'
  );
  PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;


/* -----------------------------------------------------------
   4) Prozedur: Alle Tabellen eines Schemas (einmalig) ausrüsten
   ----------------------------------------------------------- */

DELIMITER $$

CREATE PROCEDURE JWX_LOG.sp_enable_audit_for_schema(IN p_db VARCHAR(64))
SQL SECURITY DEFINER
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE v_table VARCHAR(64);

  DECLARE cur CURSOR FOR
    SELECT t.TABLE_NAME
      FROM INFORMATION_SCHEMA.TABLES t
     WHERE t.TABLE_SCHEMA = p_db
       AND t.TABLE_TYPE   = 'BASE TABLE';

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO v_table;
    IF done = 1 THEN LEAVE read_loop; END IF;

    CALL JWX_LOG.sp_enable_audit_for_table(p_db, v_table);
  END LOOP;
  CLOSE cur;
END$$

DELIMITER ;


/* -----------------------------------------------------------
   5) Prozedur: SYNC-Job (nur fehlende Trigger anhängen)
      -> Minimalinvasiv; neue Spalten werden so NICHT erfasst
   ----------------------------------------------------------- */

DELIMITER $$

CREATE PROCEDURE JWX_LOG.sp_sync_audit_triggers_for_schema(IN p_db VARCHAR(64))
SQL SECURITY DEFINER
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE v_table VARCHAR(64);

  DECLARE cur CURSOR FOR
    SELECT t.TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES t
    LEFT JOIN INFORMATION_SCHEMA.TRIGGERS trg
      ON trg.TRIGGER_SCHEMA    = t.TABLE_SCHEMA
     AND trg.EVENT_OBJECT_TABLE = t.TABLE_NAME
     AND trg.TRIGGER_NAME       = CONCAT(t.TABLE_NAME, '_AI_AUDIT')  -- unsere Konvention
    WHERE t.TABLE_SCHEMA = p_db
      AND t.TABLE_TYPE   = 'BASE TABLE'
      AND trg.TRIGGER_NAME IS NULL
      AND NOT EXISTS (
            SELECT 1 FROM JWX_LOG.audit_skip s
            WHERE s.table_schema = t.TABLE_SCHEMA
              AND s.table_name   = t.TABLE_NAME
          );

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO v_table;
    IF done = 1 THEN LEAVE read_loop; END IF;

    CALL JWX_LOG.sp_enable_audit_for_table(p_db, v_table);
  END LOOP;
  CLOSE cur;
END$$

DELIMITER ;


/* -----------------------------------------------------------
   6) (Alternative) SYNC-Job: IMMER neu aufbauen (empfohlen,
      wenn du auch neue Spalten automatisch im JSON willst)
   ----------------------------------------------------------- */


DELIMITER $$

CREATE PROCEDURE JWX_LOG.sp_sync_audit_triggers_for_schema_rebuild(IN p_db VARCHAR(64))
SQL SECURITY DEFINER
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE v_table VARCHAR(64);

  DECLARE cur CURSOR FOR
    SELECT t.TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES t
    WHERE t.TABLE_SCHEMA = p_db
      AND t.TABLE_TYPE   = 'BASE TABLE'
      AND NOT EXISTS (
            SELECT 1 FROM JWX_LOG.audit_skip s
            WHERE s.table_schema = t.TABLE_SCHEMA
              AND s.table_name   = t.TABLE_NAME
          );

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO v_table;
    IF done = 1 THEN LEAVE read_loop; END IF;

    -- Drop & Neuaufbau für JEDE Tabelle (damit neue Spalten ins JSON kommen)
    CALL JWX_LOG.sp_enable_audit_for_table(p_db, v_table);
  END LOOP;
  CLOSE cur;
END$$

DELIMITER ;



/* -----------------------------------------------------------
   7) Ereignis: regelmäßiger Sync für Schema 'JWX'
   ----------------------------------------------------------- */

-- Variante A: nur fehlende Trigger anhängen
--CREATE EVENT IF NOT EXISTS JWX_LOG.ev_audit_sync_jwx
--ON SCHEDULE EVERY 1 MINUTE
--DO CALL JWX_LOG.sp_sync_audit_triggers_for_schema('JWX');

-- Variante B (auskommentiert): IMMER neu aufbauen	

 CREATE EVENT IF NOT EXISTS JWX_LOG.ev_audit_sync_jwx
 ON SCHEDULE EVERY 1 MINUTE
 DO CALL JWX_LOG.sp_sync_audit_triggers_for_schema_rebuild('JWX');


/* -----------------------------------------------------------
   8) (Optional) Retention/Cleanup – alte Logs löschen (z. B. > 90 Tage)
   ----------------------------------------------------------- */

-- CREATE EVENT IF NOT EXISTS JWX_LOG.ev_audit_retention
-- ON SCHEDULE EVERY 1 DAY
-- DO
--   DELETE FROM JWX_LOG.audit_event
--   WHERE event_time < NOW() - INTERVAL 90 DAY;
