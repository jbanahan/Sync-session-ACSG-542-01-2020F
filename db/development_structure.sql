CREATE TABLE `addresses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `line_1` varchar(255) DEFAULT NULL,
  `line_2` varchar(255) DEFAULT NULL,
  `line_3` varchar(255) DEFAULT NULL,
  `city` varchar(255) DEFAULT NULL,
  `state` varchar(255) DEFAULT NULL,
  `postal_code` varchar(255) DEFAULT NULL,
  `company_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `country_id` int(11) DEFAULT NULL,
  `shipping` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_addresses_on_company_id` (`company_id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=latin1;

CREATE TABLE `attachment_types` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;

CREATE TABLE `attachments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `attachable_id` int(11) DEFAULT NULL,
  `attachable_type` varchar(255) DEFAULT NULL,
  `attached_file_name` varchar(255) DEFAULT NULL,
  `attached_content_type` varchar(255) DEFAULT NULL,
  `attached_file_size` int(11) DEFAULT NULL,
  `attached_updated_at` datetime DEFAULT NULL,
  `uploaded_by_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `attachment_type` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_attachments_on_attachable_id_and_attachable_type` (`attachable_id`,`attachable_type`)
) ENGINE=InnoDB AUTO_INCREMENT=32 DEFAULT CHARSET=latin1;

CREATE TABLE `change_record_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `change_record_id` int(11) DEFAULT NULL,
  `message` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3480 DEFAULT CHARSET=latin1;

CREATE TABLE `change_records` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `file_import_result_id` int(11) DEFAULT NULL,
  `recordable_id` int(11) DEFAULT NULL,
  `recordable_type` varchar(255) DEFAULT NULL,
  `record_sequence_number` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `failed` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_change_records_on_file_import_result_id` (`file_import_result_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2437 DEFAULT CHARSET=latin1;

CREATE TABLE `classifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `country_id` int(11) DEFAULT NULL,
  `binding_ruling_number` varchar(255) DEFAULT NULL,
  `product_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_classifications_on_product_id` (`product_id`),
  KEY `index_classifications_on_country_id` (`country_id`)
) ENGINE=InnoDB AUTO_INCREMENT=614 DEFAULT CHARSET=latin1;

CREATE TABLE `comments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `body` text,
  `subject` varchar(255) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `commentable_id` int(11) DEFAULT NULL,
  `commentable_type` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_comments_on_commentable_id_and_commentable_type` (`commentable_id`,`commentable_type`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=latin1;

CREATE TABLE `companies` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `carrier` tinyint(1) DEFAULT NULL,
  `vendor` tinyint(1) DEFAULT NULL,
  `master` tinyint(1) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `locked` tinyint(1) DEFAULT NULL,
  `customer` tinyint(1) DEFAULT NULL,
  `system_code` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_companies_on_carrier` (`carrier`),
  KEY `index_companies_on_vendor` (`vendor`),
  KEY `index_companies_on_master` (`master`),
  KEY `index_companies_on_customer` (`customer`)
) ENGINE=InnoDB AUTO_INCREMENT=219 DEFAULT CHARSET=latin1;

CREATE TABLE `countries` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `iso_code` varchar(2) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `import_location` tinyint(1) DEFAULT NULL,
  `classification_rank` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1560 DEFAULT CHARSET=latin1;

CREATE TABLE `custom_definitions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `label` varchar(255) DEFAULT NULL,
  `data_type` varchar(255) DEFAULT NULL,
  `rank` int(11) DEFAULT NULL,
  `module_type` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `tool_tip` varchar(255) DEFAULT NULL,
  `default_value` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_custom_definitions_on_module_type` (`module_type`)
) ENGINE=InnoDB AUTO_INCREMENT=70 DEFAULT CHARSET=latin1;

CREATE TABLE `custom_values` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `customizable_id` int(11) DEFAULT NULL,
  `customizable_type` varchar(255) DEFAULT NULL,
  `string_value` varchar(255) DEFAULT NULL,
  `decimal_value` decimal(13,4) DEFAULT NULL,
  `integer_value` int(11) DEFAULT NULL,
  `date_value` date DEFAULT NULL,
  `custom_definition_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `text_value` text,
  `boolean_value` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `cv_unique_composite` (`customizable_id`,`customizable_type`,`custom_definition_id`),
  KEY `index_custom_values_on_customizable_id_and_customizable_type` (`customizable_id`,`customizable_type`),
  KEY `index_custom_values_on_custom_definition_id` (`custom_definition_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1173 DEFAULT CHARSET=latin1;

CREATE TABLE `dashboard_widgets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `search_setup_id` int(11) DEFAULT NULL,
  `rank` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_dashboard_widgets_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `debug_records` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `request_method` varchar(255) DEFAULT NULL,
  `request_params` text,
  `request_path` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=137 DEFAULT CHARSET=latin1;

CREATE TABLE `deliveries` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ship_from_id` int(11) DEFAULT NULL,
  `ship_to_id` int(11) DEFAULT NULL,
  `carrier_id` int(11) DEFAULT NULL,
  `reference` varchar(255) DEFAULT NULL,
  `mode` varchar(255) DEFAULT NULL,
  `customer_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=latin1;

CREATE TABLE `delivery_lines` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `line_number` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `delivery_id` int(11) DEFAULT NULL,
  `product_id` int(11) DEFAULT NULL,
  `quantity` decimal(13,4) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_delivery_lines_on_delivery_id` (`delivery_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;

CREATE TABLE `divisions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `company_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;

CREATE TABLE `entity_snapshots` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `recordable_type` varchar(255) DEFAULT NULL,
  `recordable_id` int(11) DEFAULT NULL,
  `snapshot` text,
  `user_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_entity_snapshots_on_recordable_id_and_recordable_type` (`recordable_id`,`recordable_type`),
  KEY `index_entity_snapshots_on_user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1179 DEFAULT CHARSET=latin1;

CREATE TABLE `entity_type_fields` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `model_field_uid` varchar(255) DEFAULT NULL,
  `entity_type_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_entity_type_fields_on_entity_type_id` (`entity_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `entity_types` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `module_type` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `field_labels` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `model_field_uid` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_field_labels_on_model_field_uid` (`model_field_uid`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=latin1;

CREATE TABLE `field_validator_rules` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `model_field_uid` varchar(255) DEFAULT NULL,
  `module_type` varchar(255) DEFAULT NULL,
  `greater_than` decimal(13,4) DEFAULT NULL,
  `less_than` decimal(13,4) DEFAULT NULL,
  `more_than_ago` int(11) DEFAULT NULL,
  `less_than_from_now` int(11) DEFAULT NULL,
  `more_than_ago_uom` varchar(255) DEFAULT NULL,
  `less_than_from_now_uom` varchar(255) DEFAULT NULL,
  `greater_than_date` date DEFAULT NULL,
  `less_than_date` date DEFAULT NULL,
  `regex` varchar(255) DEFAULT NULL,
  `comment` text,
  `custom_message` varchar(255) DEFAULT NULL,
  `required` tinyint(1) DEFAULT NULL,
  `starts_with` varchar(255) DEFAULT NULL,
  `ends_with` varchar(255) DEFAULT NULL,
  `contains` varchar(255) DEFAULT NULL,
  `one_of` text,
  `minimum_length` int(11) DEFAULT NULL,
  `maximum_length` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `custom_definition_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=latin1;

CREATE TABLE `file_import_results` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `imported_file_id` int(11) DEFAULT NULL,
  `started_at` datetime DEFAULT NULL,
  `finished_at` datetime DEFAULT NULL,
  `run_by_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_file_import_results_on_imported_file_id_and_finished_at` (`imported_file_id`,`finished_at`)
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=latin1;

CREATE TABLE `histories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `order_id` int(11) DEFAULT NULL,
  `shipment_id` int(11) DEFAULT NULL,
  `product_id` int(11) DEFAULT NULL,
  `company_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `order_line_id` int(11) DEFAULT NULL,
  `walked` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `history_type` varchar(255) DEFAULT NULL,
  `sales_order_id` int(11) DEFAULT NULL,
  `sales_order_line_id` int(11) DEFAULT NULL,
  `delivery_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=601 DEFAULT CHARSET=latin1;

CREATE TABLE `history_details` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `history_id` int(11) DEFAULT NULL,
  `source_key` varchar(255) DEFAULT NULL,
  `value` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1132 DEFAULT CHARSET=latin1;

CREATE TABLE `imported_files` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `processed_at` datetime DEFAULT NULL,
  `search_setup_id` int(11) DEFAULT NULL,
  `ignore_first_row` tinyint(1) DEFAULT NULL,
  `attached_file_name` varchar(255) DEFAULT NULL,
  `attached_content_type` varchar(255) DEFAULT NULL,
  `attached_file_size` int(11) DEFAULT NULL,
  `attached_updated_at` datetime DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `module_type` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_imported_files_on_user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=latin1;

CREATE TABLE `item_change_subscriptions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `order_id` int(11) DEFAULT NULL,
  `shipment_id` int(11) DEFAULT NULL,
  `product_id` int(11) DEFAULT NULL,
  `app_message` tinyint(1) DEFAULT NULL,
  `email` tinyint(1) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `sales_order_id` int(11) DEFAULT NULL,
  `delivery_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;

CREATE TABLE `locations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `locode` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `sub_division` varchar(255) DEFAULT NULL,
  `function` varchar(255) DEFAULT NULL,
  `status` varchar(255) DEFAULT NULL,
  `iata` varchar(255) DEFAULT NULL,
  `coordinates` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `master_setups` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `logo_image` varchar(255) DEFAULT NULL,
  `system_code` varchar(255) DEFAULT NULL,
  `order_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `shipment_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `sales_order_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `delivery_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `classification_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `ftp_polling_active` tinyint(1) DEFAULT NULL,
  `system_message` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;

CREATE TABLE `messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` varchar(255) DEFAULT NULL,
  `subject` varchar(255) DEFAULT NULL,
  `body` varchar(255) DEFAULT NULL,
  `folder` varchar(255) DEFAULT 'inbox',
  `viewed` tinyint(1) DEFAULT '0',
  `link_name` varchar(255) DEFAULT NULL,
  `link_path` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_messages_on_user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=118 DEFAULT CHARSET=latin1;

CREATE TABLE `milestone_definitions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `milestone_plan_id` int(11) DEFAULT NULL,
  `model_field_uid` varchar(255) DEFAULT NULL,
  `days_after_previous` int(11) DEFAULT NULL,
  `previous_milestone_definition_id` int(11) DEFAULT NULL,
  `final_milestone` tinyint(1) DEFAULT NULL,
  `custom_definition_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_milestone_definitions_on_milestone_plan_id` (`milestone_plan_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=latin1;

CREATE TABLE `milestone_forecast_sets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `piece_set_id` int(11) DEFAULT NULL,
  `state` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `one_per_piece_set` (`piece_set_id`),
  KEY `mfs_state` (`state`)
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=latin1;

CREATE TABLE `milestone_forecasts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `milestone_definition_id` int(11) DEFAULT NULL,
  `milestone_forecast_set_id` int(11) DEFAULT NULL,
  `planned` date DEFAULT NULL,
  `forecast` date DEFAULT NULL,
  `state` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_forecasts` (`milestone_forecast_set_id`,`milestone_definition_id`),
  KEY `mf_state` (`state`)
) ENGINE=InnoDB AUTO_INCREMENT=81 DEFAULT CHARSET=latin1;

CREATE TABLE `milestone_plans` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `code` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;

CREATE TABLE `official_quotas` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `hts_code` varchar(255) DEFAULT NULL,
  `country_id` int(11) DEFAULT NULL,
  `square_meter_equivalent_factor` decimal(13,4) DEFAULT NULL,
  `category` varchar(255) DEFAULT NULL,
  `unit_of_measure` varchar(255) DEFAULT NULL,
  `official_tariff_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_official_quotas_on_country_id_and_hts_code` (`country_id`,`hts_code`)
) ENGINE=InnoDB AUTO_INCREMENT=5061 DEFAULT CHARSET=latin1;

CREATE TABLE `official_tariff_meta_datas` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `hts_code` varchar(255) DEFAULT NULL,
  `country_id` int(11) DEFAULT NULL,
  `auto_classify_ignore` tinyint(1) DEFAULT NULL,
  `notes` text,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_official_tariff_meta_datas_on_country_id_and_hts_code` (`country_id`,`hts_code`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;

CREATE TABLE `official_tariffs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `country_id` int(11) DEFAULT NULL,
  `hts_code` varchar(255) DEFAULT NULL,
  `full_description` text,
  `special_rates` varchar(255) DEFAULT NULL,
  `general_rate` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `chapter` varchar(800) DEFAULT NULL,
  `heading` varchar(800) DEFAULT NULL,
  `sub_heading` varchar(800) DEFAULT NULL,
  `remaining_description` varchar(800) DEFAULT NULL,
  `add_valorem_rate` varchar(255) DEFAULT NULL,
  `per_unit_rate` varchar(255) DEFAULT NULL,
  `calculation_method` varchar(255) DEFAULT NULL,
  `most_favored_nation_rate` varchar(255) DEFAULT NULL,
  `general_preferential_tariff_rate` varchar(255) DEFAULT NULL,
  `erga_omnes_rate` varchar(255) DEFAULT NULL,
  `unit_of_measure` varchar(255) DEFAULT NULL,
  `column_2_rate` varchar(255) DEFAULT NULL,
  `import_regulations` varchar(255) DEFAULT NULL,
  `export_regulations` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_official_tariffs_on_hts_code` (`hts_code`),
  KEY `index_official_tariffs_on_country_id_and_hts_code` (`country_id`,`hts_code`)
) ENGINE=InnoDB AUTO_INCREMENT=366550 DEFAULT CHARSET=latin1;

CREATE TABLE `order_lines` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `price_per_unit` decimal(13,4) DEFAULT NULL,
  `order_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `line_number` int(11) DEFAULT NULL,
  `product_id` int(11) DEFAULT NULL,
  `quantity` decimal(13,4) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_order_lines_on_order_id` (`order_id`)
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=latin1;

CREATE TABLE `orders` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `order_number` varchar(255) DEFAULT NULL,
  `order_date` date DEFAULT NULL,
  `division_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `vendor_id` int(11) DEFAULT NULL,
  `ship_to_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=104 DEFAULT CHARSET=latin1;

CREATE TABLE `piece_sets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `order_line_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `quantity` decimal(13,4) DEFAULT NULL,
  `adjustment_type` varchar(255) DEFAULT NULL,
  `sales_order_line_id` int(11) DEFAULT NULL,
  `unshipped_remainder` tinyint(1) DEFAULT NULL,
  `shipment_line_id` int(11) DEFAULT NULL,
  `delivery_line_id` int(11) DEFAULT NULL,
  `milestone_plan_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=36 DEFAULT CHARSET=latin1;

CREATE TABLE `products` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `unique_identifier` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `vendor_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `division_id` int(11) DEFAULT NULL,
  `unit_of_measure` varchar(255) DEFAULT NULL,
  `status_rule_id` int(11) DEFAULT NULL,
  `changed_at` datetime DEFAULT NULL,
  `entity_type_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_products_on_unique_identifier` (`unique_identifier`),
  KEY `index_products_on_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=219 DEFAULT CHARSET=latin1;

CREATE TABLE `public_fields` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `model_field_uid` varchar(255) DEFAULT NULL,
  `searchable` tinyint(1) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_public_fields_on_model_field_uid` (`model_field_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `sales_order_lines` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `price_per_unit` decimal(13,4) DEFAULT NULL,
  `sales_order_id` int(11) DEFAULT NULL,
  `line_number` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `product_id` int(11) DEFAULT NULL,
  `quantity` decimal(13,4) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_sales_order_lines_on_sales_order_id` (`sales_order_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;

CREATE TABLE `sales_orders` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `order_number` varchar(255) DEFAULT NULL,
  `order_date` date DEFAULT NULL,
  `customer_id` int(11) DEFAULT NULL,
  `division_id` int(11) DEFAULT NULL,
  `ship_to_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=latin1;

CREATE TABLE `schema_migrations` (
  `version` varchar(255) NOT NULL,
  UNIQUE KEY `unique_schema_migrations` (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `search_columns` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `search_setup_id` int(11) DEFAULT NULL,
  `rank` int(11) DEFAULT NULL,
  `model_field_uid` varchar(255) DEFAULT NULL,
  `custom_definition_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `imported_file_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_search_columns_on_search_setup_id` (`search_setup_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1400 DEFAULT CHARSET=latin1;

CREATE TABLE `search_criterions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `operator` varchar(255) DEFAULT NULL,
  `value` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `status_rule_id` int(11) DEFAULT NULL,
  `model_field_uid` varchar(255) DEFAULT NULL,
  `search_setup_id` int(11) DEFAULT NULL,
  `custom_definition_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_search_criterions_on_search_setup_id` (`search_setup_id`)
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=latin1;

CREATE TABLE `search_runs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `result_cache` text,
  `position` int(11) DEFAULT NULL,
  `search_setup_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `starting_cache_position` int(11) DEFAULT NULL,
  `last_accessed` datetime DEFAULT NULL,
  `imported_file_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_search_runs_on_user_id_and_last_accessed` (`user_id`,`last_accessed`)
) ENGINE=InnoDB AUTO_INCREMENT=58 DEFAULT CHARSET=latin1;

CREATE TABLE `search_schedules` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `email_addresses` varchar(255) DEFAULT NULL,
  `ftp_server` varchar(255) DEFAULT NULL,
  `ftp_username` varchar(255) DEFAULT NULL,
  `ftp_password` varchar(255) DEFAULT NULL,
  `ftp_subfolder` varchar(255) DEFAULT NULL,
  `sftp_server` varchar(255) DEFAULT NULL,
  `sftp_username` varchar(255) DEFAULT NULL,
  `sftp_password` varchar(255) DEFAULT NULL,
  `sftp_subfolder` varchar(255) DEFAULT NULL,
  `run_monday` tinyint(1) DEFAULT NULL,
  `run_tuesday` tinyint(1) DEFAULT NULL,
  `run_wednesday` tinyint(1) DEFAULT NULL,
  `run_thursday` tinyint(1) DEFAULT NULL,
  `run_friday` tinyint(1) DEFAULT NULL,
  `run_saturday` tinyint(1) DEFAULT NULL,
  `run_sunday` tinyint(1) DEFAULT NULL,
  `run_hour` int(11) DEFAULT NULL,
  `last_start_time` datetime DEFAULT NULL,
  `last_finish_time` datetime DEFAULT NULL,
  `search_setup_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `download_format` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_search_schedules_on_search_setup_id` (`search_setup_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `search_setups` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `module_type` varchar(255) DEFAULT NULL,
  `simple` tinyint(1) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `download_format` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_search_setups_on_user_id_and_module_type` (`user_id`,`module_type`)
) ENGINE=InnoDB AUTO_INCREMENT=65 DEFAULT CHARSET=latin1;

CREATE TABLE `shipment_lines` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `line_number` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `shipment_id` int(11) DEFAULT NULL,
  `product_id` int(11) DEFAULT NULL,
  `quantity` decimal(13,4) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_shipment_lines_on_shipment_id` (`shipment_id`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=latin1;

CREATE TABLE `shipments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ship_from_id` int(11) DEFAULT NULL,
  `ship_to_id` int(11) DEFAULT NULL,
  `carrier_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `reference` varchar(255) DEFAULT NULL,
  `mode` varchar(255) DEFAULT NULL,
  `vendor_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=40 DEFAULT CHARSET=latin1;

CREATE TABLE `sort_criterions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `search_setup_id` int(11) DEFAULT NULL,
  `rank` int(11) DEFAULT NULL,
  `model_field_uid` varchar(255) DEFAULT NULL,
  `custom_definition_id` int(11) DEFAULT NULL,
  `descending` tinyint(1) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_sort_criterions_on_search_setup_id` (`search_setup_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `status_rules` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `module_type` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `test_rank` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;

CREATE TABLE `tariff_records` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `hts_1` varchar(255) DEFAULT NULL,
  `hts_2` varchar(255) DEFAULT NULL,
  `hts_3` varchar(255) DEFAULT NULL,
  `classification_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `line_number` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_tariff_records_on_classification_id` (`classification_id`)
) ENGINE=InnoDB AUTO_INCREMENT=359 DEFAULT CHARSET=latin1;

CREATE TABLE `user_sessions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(255) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `crypted_password` varchar(255) DEFAULT NULL,
  `password_salt` varchar(255) DEFAULT NULL,
  `persistence_token` varchar(255) DEFAULT NULL,
  `failed_login_count` int(11) NOT NULL DEFAULT '0',
  `last_request_at` datetime DEFAULT NULL,
  `current_login_at` datetime DEFAULT NULL,
  `last_login_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `disabled` tinyint(1) DEFAULT NULL,
  `company_id` int(11) DEFAULT NULL,
  `first_name` varchar(255) DEFAULT NULL,
  `last_name` varchar(255) DEFAULT NULL,
  `time_zone` varchar(255) DEFAULT NULL,
  `email_format` varchar(255) DEFAULT NULL,
  `admin` tinyint(1) DEFAULT NULL,
  `sys_admin` tinyint(1) DEFAULT NULL,
  `perishable_token` varchar(255) NOT NULL DEFAULT '',
  `debug_expires` datetime DEFAULT NULL,
  `tos_accept` datetime DEFAULT NULL,
  `search_open` tinyint(1) DEFAULT NULL,
  `classification_comment` tinyint(1) DEFAULT NULL,
  `classification_attach` tinyint(1) DEFAULT NULL,
  `order_view` tinyint(1) DEFAULT NULL,
  `order_edit` tinyint(1) DEFAULT NULL,
  `order_delete` tinyint(1) DEFAULT NULL,
  `order_comment` tinyint(1) DEFAULT NULL,
  `order_attach` tinyint(1) DEFAULT NULL,
  `shipment_view` tinyint(1) DEFAULT NULL,
  `shipment_edit` tinyint(1) DEFAULT NULL,
  `shipment_delete` tinyint(1) DEFAULT NULL,
  `shipment_comment` tinyint(1) DEFAULT NULL,
  `shipment_attach` tinyint(1) DEFAULT NULL,
  `sales_order_view` tinyint(1) DEFAULT NULL,
  `sales_order_edit` tinyint(1) DEFAULT NULL,
  `sales_order_delete` tinyint(1) DEFAULT NULL,
  `sales_order_comment` tinyint(1) DEFAULT NULL,
  `sales_order_attach` tinyint(1) DEFAULT NULL,
  `delivery_view` tinyint(1) DEFAULT NULL,
  `delivery_edit` tinyint(1) DEFAULT NULL,
  `delivery_delete` tinyint(1) DEFAULT NULL,
  `delivery_comment` tinyint(1) DEFAULT NULL,
  `delivery_attach` tinyint(1) DEFAULT NULL,
  `product_view` tinyint(1) DEFAULT NULL,
  `product_edit` tinyint(1) DEFAULT NULL,
  `product_delete` tinyint(1) DEFAULT NULL,
  `product_comment` tinyint(1) DEFAULT NULL,
  `product_attach` tinyint(1) DEFAULT NULL,
  `classification_edit` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=latin1;

CREATE TABLE `worksheet_config_mappings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `row` int(11) DEFAULT NULL,
  `column` int(11) DEFAULT NULL,
  `model_field_uid` varchar(255) DEFAULT NULL,
  `custom_definition_id` int(11) DEFAULT NULL,
  `worksheet_config_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=latin1;

CREATE TABLE `worksheet_configs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `module_type` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;

INSERT INTO schema_migrations (version) VALUES ('20100906132335');

INSERT INTO schema_migrations (version) VALUES ('20100906133303');

INSERT INTO schema_migrations (version) VALUES ('20100906233840');

INSERT INTO schema_migrations (version) VALUES ('20100906234150');

INSERT INTO schema_migrations (version) VALUES ('20100908004342');

INSERT INTO schema_migrations (version) VALUES ('20100909011443');

INSERT INTO schema_migrations (version) VALUES ('20100910014640');

INSERT INTO schema_migrations (version) VALUES ('20100910023035');

INSERT INTO schema_migrations (version) VALUES ('20100910023617');

INSERT INTO schema_migrations (version) VALUES ('20100910033319');

INSERT INTO schema_migrations (version) VALUES ('20100914013930');

INSERT INTO schema_migrations (version) VALUES ('20100915003637');

INSERT INTO schema_migrations (version) VALUES ('20100924014742');

INSERT INTO schema_migrations (version) VALUES ('20100925012908');

INSERT INTO schema_migrations (version) VALUES ('20100925025732');

INSERT INTO schema_migrations (version) VALUES ('20100926020902');

INSERT INTO schema_migrations (version) VALUES ('20101003172057');

INSERT INTO schema_migrations (version) VALUES ('20101003175458');

INSERT INTO schema_migrations (version) VALUES ('20101009003826');

INSERT INTO schema_migrations (version) VALUES ('20101009011448');

INSERT INTO schema_migrations (version) VALUES ('20101009140215');

INSERT INTO schema_migrations (version) VALUES ('20101009141452');

INSERT INTO schema_migrations (version) VALUES ('20101009153101');

INSERT INTO schema_migrations (version) VALUES ('20101016222322');

INSERT INTO schema_migrations (version) VALUES ('20101024145916');

INSERT INTO schema_migrations (version) VALUES ('20101024150040');

INSERT INTO schema_migrations (version) VALUES ('20101024155652');

INSERT INTO schema_migrations (version) VALUES ('20101025012521');

INSERT INTO schema_migrations (version) VALUES ('20101027001445');

INSERT INTO schema_migrations (version) VALUES ('20101029012524');

INSERT INTO schema_migrations (version) VALUES ('20101101011007');

INSERT INTO schema_migrations (version) VALUES ('20101109023655');

INSERT INTO schema_migrations (version) VALUES ('20101111031622');

INSERT INTO schema_migrations (version) VALUES ('20101111031958');

INSERT INTO schema_migrations (version) VALUES ('20101113134259');

INSERT INTO schema_migrations (version) VALUES ('20101116025854');

INSERT INTO schema_migrations (version) VALUES ('20101124011335');

INSERT INTO schema_migrations (version) VALUES ('20101214032431');

INSERT INTO schema_migrations (version) VALUES ('20101214032519');

INSERT INTO schema_migrations (version) VALUES ('20101214134510');

INSERT INTO schema_migrations (version) VALUES ('20101215010936');

INSERT INTO schema_migrations (version) VALUES ('20101218195450');

INSERT INTO schema_migrations (version) VALUES ('20101218195531');

INSERT INTO schema_migrations (version) VALUES ('20101223195348');

INSERT INTO schema_migrations (version) VALUES ('20101225221552');

INSERT INTO schema_migrations (version) VALUES ('20101225221632');

INSERT INTO schema_migrations (version) VALUES ('20101226190752');

INSERT INTO schema_migrations (version) VALUES ('20101226190839');

INSERT INTO schema_migrations (version) VALUES ('20101226191549');

INSERT INTO schema_migrations (version) VALUES ('20101226191712');

INSERT INTO schema_migrations (version) VALUES ('20101227020810');

INSERT INTO schema_migrations (version) VALUES ('20101227020942');

INSERT INTO schema_migrations (version) VALUES ('20110103204919');

INSERT INTO schema_migrations (version) VALUES ('20110103211035');

INSERT INTO schema_migrations (version) VALUES ('20110103211123');

INSERT INTO schema_migrations (version) VALUES ('20110103211232');

INSERT INTO schema_migrations (version) VALUES ('20110103212111');

INSERT INTO schema_migrations (version) VALUES ('20110105202927');

INSERT INTO schema_migrations (version) VALUES ('20110105205240');

INSERT INTO schema_migrations (version) VALUES ('20110109234240');

INSERT INTO schema_migrations (version) VALUES ('20110109235157');

INSERT INTO schema_migrations (version) VALUES ('20110110000646');

INSERT INTO schema_migrations (version) VALUES ('20110110002759');

INSERT INTO schema_migrations (version) VALUES ('20110110005740');

INSERT INTO schema_migrations (version) VALUES ('20110110012824');

INSERT INTO schema_migrations (version) VALUES ('20110110013408');

INSERT INTO schema_migrations (version) VALUES ('20110111141448');

INSERT INTO schema_migrations (version) VALUES ('20110111143117');

INSERT INTO schema_migrations (version) VALUES ('20110112212044');

INSERT INTO schema_migrations (version) VALUES ('20110117163914');

INSERT INTO schema_migrations (version) VALUES ('20110117183750');

INSERT INTO schema_migrations (version) VALUES ('20110117193151');

INSERT INTO schema_migrations (version) VALUES ('20110117214144');

INSERT INTO schema_migrations (version) VALUES ('20110121173902');

INSERT INTO schema_migrations (version) VALUES ('20110121180707');

INSERT INTO schema_migrations (version) VALUES ('20110121191352');

INSERT INTO schema_migrations (version) VALUES ('20110121210015');

INSERT INTO schema_migrations (version) VALUES ('20110121211008');

INSERT INTO schema_migrations (version) VALUES ('20110123024054');

INSERT INTO schema_migrations (version) VALUES ('20110125174046');

INSERT INTO schema_migrations (version) VALUES ('20110125201939');

INSERT INTO schema_migrations (version) VALUES ('20110125202136');

INSERT INTO schema_migrations (version) VALUES ('20110125202332');

INSERT INTO schema_migrations (version) VALUES ('20110125202641');

INSERT INTO schema_migrations (version) VALUES ('20110125203913');

INSERT INTO schema_migrations (version) VALUES ('20110127151344');

INSERT INTO schema_migrations (version) VALUES ('20110127165608');

INSERT INTO schema_migrations (version) VALUES ('20110201175559');

INSERT INTO schema_migrations (version) VALUES ('20110201181812');

INSERT INTO schema_migrations (version) VALUES ('20110203172708');

INSERT INTO schema_migrations (version) VALUES ('20110203185322');

INSERT INTO schema_migrations (version) VALUES ('20110205172835');

INSERT INTO schema_migrations (version) VALUES ('20110205203425');

INSERT INTO schema_migrations (version) VALUES ('20110205230609');

INSERT INTO schema_migrations (version) VALUES ('20110207213508');

INSERT INTO schema_migrations (version) VALUES ('20110207225316');

INSERT INTO schema_migrations (version) VALUES ('20110208003221');

INSERT INTO schema_migrations (version) VALUES ('20110208171428');

INSERT INTO schema_migrations (version) VALUES ('20110208210029');

INSERT INTO schema_migrations (version) VALUES ('20110213150837');

INSERT INTO schema_migrations (version) VALUES ('20110214183155');

INSERT INTO schema_migrations (version) VALUES ('20110214235350');

INSERT INTO schema_migrations (version) VALUES ('20110214235611');

INSERT INTO schema_migrations (version) VALUES ('20110217024555');

INSERT INTO schema_migrations (version) VALUES ('20110220184903');

INSERT INTO schema_migrations (version) VALUES ('20110222163121');

INSERT INTO schema_migrations (version) VALUES ('20110222163508');

INSERT INTO schema_migrations (version) VALUES ('20110301170311');

INSERT INTO schema_migrations (version) VALUES ('20110304201026');

INSERT INTO schema_migrations (version) VALUES ('20110307175658');

INSERT INTO schema_migrations (version) VALUES ('20110314173210');

INSERT INTO schema_migrations (version) VALUES ('20110314173358');

INSERT INTO schema_migrations (version) VALUES ('20110314173844');

INSERT INTO schema_migrations (version) VALUES ('20110314185659');

INSERT INTO schema_migrations (version) VALUES ('20110314193542');

INSERT INTO schema_migrations (version) VALUES ('20110315202025');

INSERT INTO schema_migrations (version) VALUES ('20110318164534');

INSERT INTO schema_migrations (version) VALUES ('20110320011318');

INSERT INTO schema_migrations (version) VALUES ('20110320134447');

INSERT INTO schema_migrations (version) VALUES ('20110320155927');

INSERT INTO schema_migrations (version) VALUES ('20110320165011');

INSERT INTO schema_migrations (version) VALUES ('20110322132530');

INSERT INTO schema_migrations (version) VALUES ('20110322135242');

INSERT INTO schema_migrations (version) VALUES ('20110323021108');

INSERT INTO schema_migrations (version) VALUES ('20110323231601');

INSERT INTO schema_migrations (version) VALUES ('20110324145759');

INSERT INTO schema_migrations (version) VALUES ('20110329171023');

INSERT INTO schema_migrations (version) VALUES ('20110331154157');

INSERT INTO schema_migrations (version) VALUES ('20110404200550');

INSERT INTO schema_migrations (version) VALUES ('20110409173417');

INSERT INTO schema_migrations (version) VALUES ('20110413010350');

INSERT INTO schema_migrations (version) VALUES ('20110413193020');

INSERT INTO schema_migrations (version) VALUES ('20110418203150');

INSERT INTO schema_migrations (version) VALUES ('20110419145628');

INSERT INTO schema_migrations (version) VALUES ('20110422142626');

INSERT INTO schema_migrations (version) VALUES ('20110422144759');

INSERT INTO schema_migrations (version) VALUES ('20110422152953');

INSERT INTO schema_migrations (version) VALUES ('20110422154310');

INSERT INTO schema_migrations (version) VALUES ('20110422180414');

INSERT INTO schema_migrations (version) VALUES ('20110422191809');

INSERT INTO schema_migrations (version) VALUES ('20110422211854');

INSERT INTO schema_migrations (version) VALUES ('20110423015934');

INSERT INTO schema_migrations (version) VALUES ('20110424224032');

INSERT INTO schema_migrations (version) VALUES ('20110425154552');

INSERT INTO schema_migrations (version) VALUES ('20110425193023');

INSERT INTO schema_migrations (version) VALUES ('20110425194806');

INSERT INTO schema_migrations (version) VALUES ('20110425195248');

INSERT INTO schema_migrations (version) VALUES ('20110425195555');

INSERT INTO schema_migrations (version) VALUES ('20110426004145');

INSERT INTO schema_migrations (version) VALUES ('20110509142738');

INSERT INTO schema_migrations (version) VALUES ('20110510203259');

INSERT INTO schema_migrations (version) VALUES ('20110511172400');

INSERT INTO schema_migrations (version) VALUES ('20110511181750');

INSERT INTO schema_migrations (version) VALUES ('20110516175125');

INSERT INTO schema_migrations (version) VALUES ('20110524134750');

INSERT INTO schema_migrations (version) VALUES ('20110527185128');

INSERT INTO schema_migrations (version) VALUES ('20110527185206');

INSERT INTO schema_migrations (version) VALUES ('20110528204736');

INSERT INTO schema_migrations (version) VALUES ('20110531132152');

INSERT INTO schema_migrations (version) VALUES ('20110606130142');

INSERT INTO schema_migrations (version) VALUES ('20110606191809');

INSERT INTO schema_migrations (version) VALUES ('20110611143814');

INSERT INTO schema_migrations (version) VALUES ('20110614234618');

INSERT INTO schema_migrations (version) VALUES ('20110620140633');

INSERT INTO schema_migrations (version) VALUES ('20110620184914');

INSERT INTO schema_migrations (version) VALUES ('20110624141957');

INSERT INTO schema_migrations (version) VALUES ('20110625173822');

INSERT INTO schema_migrations (version) VALUES ('20110627155804');