CREATE TABLE IF NOT EXISTS `agc_graffiti` (
 `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
 `citizenid` VARCHAR(64) NOT NULL,
 `author_name` VARCHAR(128) NOT NULL,
 `kind` ENUM('text','image') NOT NULL,
 `content` VARCHAR(500) NOT NULL,
 `color` VARCHAR(7) NOT NULL DEFAULT '#ffffff',
 `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
 `nx` DOUBLE NOT NULL, `ny` DOUBLE NOT NULL, `nz` DOUBLE NOT NULL,
 `heading` DOUBLE NOT NULL DEFAULT 0,
 `scale` FLOAT NOT NULL DEFAULT 1,
 `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY (`id`), KEY `idx_citizenid` (`citizenid`), KEY `idx_coords` (`x`,`y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
