--
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Fri Sep 26 12:02:03 2025
--
--
-- Table: categories
--
DROP TABLE categories CASCADE;
CREATE TABLE categories (
  id bigserial NOT NULL,
  name citext NOT NULL,
  description citext,
  parent_id bigint,
  PRIMARY KEY (id),
  CONSTRAINT categories_name_key UNIQUE (name)
);
CREATE INDEX categories_idx_parent_id on categories (parent_id);

--
-- Table: dvd_csv
--
DROP TABLE dvd_csv CASCADE;
CREATE TABLE dvd_csv (
  id serial NOT NULL,
  dvd_title text,
  studio text,
  released date,
  status text,
  sound text,
  versions text,
  price money,
  rating text,
  year text,
  genre text,
  aspect text,
  upc text,
  dvd_releasedate date,
  timestamp timestamp
);

--
-- Table: locations
--
DROP TABLE locations CASCADE;
CREATE TABLE locations (
  id bigserial NOT NULL,
  short_name citext,
  full_name citext,
  parent_id bigint,
  PRIMARY KEY (id),
  CONSTRAINT idx_43370_sqlite_autoindex_locations_1 UNIQUE (short_name),
  CONSTRAINT idx_43370_sqlite_autoindex_locations_2 UNIQUE (full_name)
);
CREATE INDEX locations_idx_parent_id on locations (parent_id);

--
-- Table: tags
--
DROP TABLE tags CASCADE;
CREATE TABLE tags (
  id bigserial NOT NULL,
  tag citext,
  PRIMARY KEY (id),
  CONSTRAINT idx_43364_sqlite_autoindex_tags_1 UNIQUE (tag)
);

--
-- Table: items
--
DROP TABLE items CASCADE;
CREATE TABLE items (
  id bigserial NOT NULL,
  short_description citext,
  description citext,
  parent_id bigint,
  category_id bigint,
  PRIMARY KEY (id)
);
CREATE INDEX items_idx_category_id on items (category_id);
CREATE INDEX items_idx_parent_id on items (parent_id);

--
-- Table: gtins
--
DROP TABLE gtins CASCADE;
CREATE TABLE gtins (
  gtin bigint NOT NULL,
  item_id bigint,
  item_quantity integer DEFAULT 1 NOT NULL,
  id bigserial NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT gtins_gtin_item_id_key UNIQUE (gtin, item_id)
);
CREATE INDEX gtins_idx_item_id on gtins (item_id);

--
-- Table: patterns
--
DROP TABLE patterns CASCADE;
CREATE TABLE patterns (
  id bigserial NOT NULL,
  item_id bigint,
  lower bigint NOT NULL,
  upper bigint NOT NULL,
  comment text,
  PRIMARY KEY (id),
  CONSTRAINT patterns_lower_upper_key UNIQUE (lower, upper)
);
CREATE INDEX patterns_idx_item_id on patterns (item_id);

--
-- Table: schwans_products
--
DROP TABLE schwans_products CASCADE;
CREATE TABLE schwans_products (
  id integer NOT NULL,
  item_id bigint,
  PRIMARY KEY (id)
);
CREATE INDEX schwans_products_idx_item_id on schwans_products (item_id);

--
-- Table: inventory
--
DROP TABLE inventory CASCADE;
CREATE TABLE inventory (
  id bigserial NOT NULL,
  item_id bigint,
  location_id bigint,
  added_at timestamp DEFAULT current_timestamp,
  PRIMARY KEY (id)
);
CREATE INDEX inventory_idx_item_id on inventory (item_id);
CREATE INDEX inventory_idx_location_id on inventory (location_id);

--
-- Table: item_tags
--
DROP TABLE item_tags CASCADE;
CREATE TABLE item_tags (
  id bigserial NOT NULL,
  item_id bigint,
  tag_id bigint,
  PRIMARY KEY (id),
  CONSTRAINT idx_43379_sqlite_autoindex_item_tags_1 UNIQUE (item_id, tag_id)
);
CREATE INDEX item_tags_idx_item_id on item_tags (item_id);
CREATE INDEX item_tags_idx_tag_id on item_tags (tag_id);

--
-- Foreign Key Definitions
--

ALTER TABLE categories ADD CONSTRAINT categories_fk_parent_id FOREIGN KEY (parent_id)
  REFERENCES categories (id) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE locations ADD CONSTRAINT locations_fk_parent_id FOREIGN KEY (parent_id)
  REFERENCES locations (id) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE items ADD CONSTRAINT items_fk_category_id FOREIGN KEY (category_id)
  REFERENCES categories (id) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE items ADD CONSTRAINT items_fk_parent_id FOREIGN KEY (parent_id)
  REFERENCES items (id) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE gtins ADD CONSTRAINT gtins_fk_item_id FOREIGN KEY (item_id)
  REFERENCES items (id) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE patterns ADD CONSTRAINT patterns_fk_item_id FOREIGN KEY (item_id)
  REFERENCES items (id) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE schwans_products ADD CONSTRAINT schwans_products_fk_item_id FOREIGN KEY (item_id)
  REFERENCES items (id) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE inventory ADD CONSTRAINT inventory_fk_item_id FOREIGN KEY (item_id)
  REFERENCES items (id) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE inventory ADD CONSTRAINT inventory_fk_location_id FOREIGN KEY (location_id)
  REFERENCES locations (id) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE item_tags ADD CONSTRAINT item_tags_fk_item_id FOREIGN KEY (item_id)
  REFERENCES items (id) ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE item_tags ADD CONSTRAINT item_tags_fk_tag_id FOREIGN KEY (tag_id)
  REFERENCES tags (id) ON DELETE CASCADE ON UPDATE NO ACTION;

