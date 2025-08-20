-- created 13.08.2025 JW --

-- sudo mysql --defaults-file=/etc/mysql/debian.cnf

-- Benutzer lokal anlegen
CREATE USER IF NOT EXISTS 'jwx'@'localhost'
IDENTIFIED WITH mysql_native_password BY 'lol800';

-- Benutzer für externe Verbindungen anlegen
CREATE USER IF NOT EXISTS 'jwx'@'%'
IDENTIFIED WITH mysql_native_password BY 'lol800';

-- Vollzugriff gewähren
GRANT ALL PRIVILEGES ON *.* TO 'jwx'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'jwx'@'%' WITH GRANT OPTION;

-- Änderungen anwenden
FLUSH PRIVILEGES;
