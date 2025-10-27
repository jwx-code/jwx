USE JWX_LOG;

CREATE TABLE IF NOT EXISTS cdc_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  event_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  db_name VARCHAR(64) NOT NULL,
  table_name VARCHAR(64),
  event_type ENUM('insert','update','delete','ddl','heartbeat') NOT NULL,
  primary_key_json JSON NULL,
  row_before JSON NULL,
  row_after JSON NULL,
  ddl_sql LONGTEXT NULL,
  server_id BIGINT UNSIGNED NULL,
  binlog_file VARCHAR(64) NULL,
  binlog_pos BIGINT UNSIGNED NULL
) ENGINE=InnoDB;
