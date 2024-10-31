
CREATE TABLE IF NOT EXISTS `warehouses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `owner` varchar(100) NOT NULL,
  `steam_id` varchar(50) DEFAULT NULL,
  `discord` varchar(50) NOT NULL,
  `name` varchar(100) NOT NULL,
  `code` varchar(4) NOT NULL,
  `location` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`location`)),
  `warehouse_id` int(11) NOT NULL,
  `entry_coords` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`entry_coords`)),
  `max_slots` int(11) DEFAULT 50,
  `max_weight` int(11) DEFAULT 50000,
  `original_price` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `warehouse_id_UNIQUE` (`warehouse_id`),
  UNIQUE KEY `name_UNIQUE` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=45 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;


