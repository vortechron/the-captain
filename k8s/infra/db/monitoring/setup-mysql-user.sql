-- Create monitoring user for MySQL Exporter
-- Run this inside MySQL to create the exporter user

-- Create the exporter user with minimal required privileges
CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY 'exporterpassword123';

-- Grant necessary privileges for monitoring
GRANT PROCESS ON *.* TO 'exporter'@'%';
GRANT REPLICATION CLIENT ON *.* TO 'exporter'@'%';
GRANT SELECT ON performance_schema.* TO 'exporter'@'%';
GRANT SELECT ON information_schema.* TO 'exporter'@'%';

-- Optional: Grant additional privileges for more detailed metrics
GRANT SELECT ON mysql.slave_relay_log_info TO 'exporter'@'%';
GRANT SELECT ON mysql.slave_master_info TO 'exporter'@'%';

-- Flush privileges to apply changes
FLUSH PRIVILEGES;

-- Verify the user was created
SELECT User, Host FROM mysql.user WHERE User = 'exporter';

-- Show granted privileges
SHOW GRANTS FOR 'exporter'@'%';