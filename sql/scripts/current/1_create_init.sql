sudo tee /etc/mysql/my.cnf > /dev/null <<'EOF'
[mysqld]
server_id=1
log_bin=ON
binlog_format=ROW
binlog_row_image=FULL
binlog_expire_logs_seconds=604800
character_set_server=utf8mb4
collation_server=utf8mb4_unicode_ci

[client]
default-character-set=utf8mb4
EOF

sudo systemctl restart mysql
