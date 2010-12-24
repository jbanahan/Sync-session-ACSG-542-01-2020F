CREATE TABLE "addresses" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar(255), "line_1" varchar(255), "line_2" varchar(255), "line_3" varchar(255), "city" varchar(255), "state" varchar(255), "postal_code" varchar(255), "company_id" integer, "created_at" datetime, "updated_at" datetime, "country_id" integer, "shipping" boolean);
CREATE TABLE "companies" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar(255), "carrier" boolean, "vendor" boolean, "master" boolean, "created_at" datetime, "updated_at" datetime);
CREATE TABLE "countries" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar(255), "iso_code" varchar(2), "created_at" datetime, "updated_at" datetime);
CREATE TABLE "divisions" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar(255), "company_id" integer, "created_at" datetime, "updated_at" datetime);
CREATE TABLE "locations" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "locode" varchar(255), "name" varchar(255), "sub_division" varchar(255), "function" varchar(255), "status" varchar(255), "iata" varchar(255), "coordinates" varchar(255), "created_at" datetime, "updated_at" datetime);
CREATE TABLE "order_lines" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "product_id" integer, "ordered_qty" decimal, "unit_of_measure" varchar(255), "price_per_unit" decimal, "expected_ship_date" date, "expected_delivery_date" date, "ship_no_later_date" date, "order_id" integer, "created_at" datetime, "updated_at" datetime);
CREATE TABLE "orders" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "order_number" varchar(255), "order_date" date, "buyer" varchar(255), "season" varchar(255), "division_id" integer, "created_at" datetime, "updated_at" datetime, "vendor_id" integer);
CREATE TABLE "piece_sets" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "order_line_id" integer, "shipment_id" integer, "product_id" integer, "created_at" datetime, "updated_at" datetime, "quantity" decimal);
CREATE TABLE "products" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "unique_identifier" varchar(255), "part_number" varchar(255), "name" varchar(255), "description" varchar(255), "vendor_id" integer, "created_at" datetime, "updated_at" datetime, "division_id" integer);
CREATE TABLE "schema_migrations" ("version" varchar(255) NOT NULL);
CREATE TABLE "shipments" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "eta" date, "etd" date, "ata" date, "atd" date, "ship_from_id" integer, "ship_to_id" integer, "carrier_id" integer, "created_at" datetime, "updated_at" datetime, "reference" varchar(255), "bill_of_lading" varchar(255), "mode" varchar(255));
CREATE TABLE "user_sessions" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "username" varchar(255), "password" varchar(255), "created_at" datetime, "updated_at" datetime);
CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "username" varchar(255), "email" varchar(255), "crypted_password" varchar(255), "password_salt" varchar(255), "persistence_token" varchar(255), "failed_login_count" integer DEFAULT 0 NOT NULL, "last_request_at" datetime, "current_login_at" datetime, "last_login_at" datetime, "created_at" datetime, "updated_at" datetime, "disabled" boolean, "company_id" integer, "first_name" varchar(255), "last_name" varchar(255));
CREATE UNIQUE INDEX "unique_schema_migrations" ON "schema_migrations" ("version");
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