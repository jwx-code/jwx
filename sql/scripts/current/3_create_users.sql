-- ============================================================
-- Benutzer + Rechte für JWX, JWX_LOG und Maxwell
-- MySQL 8.x – kompatibel mit caching_sha2_password
-- ============================================================

-- 1) Benutzer für App (JWX)
CREATE USER IF NOT EXISTS 'jwx'@'localhost'
IDENTIFIED BY 'lol800mt2';

CREATE USER IF NOT EXISTS 'jwx'@'%'
IDENTIFIED BY 'lol800mt2';

GRANT ALL PRIVILEGES ON `JWX`.*     TO 'jwx'@'localhost';
GRANT ALL PRIVILEGES ON `JWX_LOG`.* TO 'jwx'@'localhost';
GRANT ALL PRIVILEGES ON `JWX`.*     TO 'jwx'@'%';
GRANT ALL PRIVILEGES ON `JWX_LOG`.* TO 'jwx'@'%';


-- ============================================================
-- 2) Benutzer für Maxwell CDC (liest Binlog, schreibt Metadaten)
-- ============================================================

CREATE USER IF NOT EXISTS 'maxwell'@'%'
IDENTIFIED BY 'lol800mt2';

-- Rechte für Binlog-Replikation (lesen)
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'maxwell'@'%';

-- Leserechte auf alle DBs (für schema info)
GRANT SELECT ON *.* TO 'maxwell'@'%';

-- Maxwell legt eigene interne Tabellen im Schema `maxwell` an
CREATE DATABASE IF NOT EXISTS `maxwell`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON `maxwell`.* TO 'maxwell'@'%';


-- ============================================================
-- 3) Anwenden
-- ============================================================

FLUSH PRIVILEGES;
