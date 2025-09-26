--
-- Created by SQL::Translator::Producer::SQLite
-- Created on Fri Sep 26 12:02:03 2025
--

BEGIN TRANSACTION;

--
-- Table: categories
--
DROP TABLE categories;

CREATE TABLE categories (
  id INTEGER PRIMARY KEY NOT NULL,
  name citext NOT NULL,
  description citext,
  parent_id bigint,
  FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE NO ACTION ON UPDATE NO ACTION
);

CREATE INDEX categories_idx_parent_id ON categories (parent_id);

CREATE UNIQUE INDEX categories_name_key ON categories (name);

--
-- Table: dvd_csv
--
DROP TABLE dvd_csv;

CREATE TABLE dvd_csv (
  id integer NOT NULL,
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
DROP TABLE locations;

CREATE TABLE locations (
  id INTEGER PRIMARY KEY NOT NULL,
  short_name citext,
  full_name citext,
  parent_id bigint,
  FOREIGN KEY (parent_id) REFERENCES locations(id) ON DELETE NO ACTION ON UPDATE NO ACTION
);

CREATE INDEX locations_idx_parent_id ON locations (parent_id);

CREATE UNIQUE INDEX idx_43370_sqlite_autoindex_locations_1 ON locations (short_name);

CREATE UNIQUE INDEX idx_43370_sqlite_autoindex_locations_2 ON locations (full_name);

--
-- Table: tags
--
DROP TABLE tags;

CREATE TABLE tags (
  id INTEGER PRIMARY KEY NOT NULL,
  tag citext
);

CREATE UNIQUE INDEX idx_43364_sqlite_autoindex_tags_1 ON tags (tag);

--
-- Table: items
--
DROP TABLE items;

CREATE TABLE items (
  id INTEGER PRIMARY KEY NOT NULL,
  short_description citext,
  description citext,
  parent_id bigint,
  category_id bigint,
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE NO ACTION ON UPDATE NO ACTION,
  FOREIGN KEY (parent_id) REFERENCES items(id) ON DELETE NO ACTION ON UPDATE NO ACTION
);

CREATE INDEX items_idx_category_id ON items (category_id);

CREATE INDEX items_idx_parent_id ON items (parent_id);

--
-- Table: gtins
--
DROP TABLE gtins;

CREATE TABLE gtins (
  gtin bigint NOT NULL,
  item_id bigint,
  item_quantity integer NOT NULL DEFAULT 1,
  id INTEGER PRIMARY KEY NOT NULL,
  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE NO ACTION ON UPDATE NO ACTION
);

CREATE INDEX gtins_idx_item_id ON gtins (item_id);

CREATE UNIQUE INDEX gtins_gtin_item_id_key ON gtins (gtin, item_id);

--
-- Table: patterns
--
DROP TABLE patterns;

CREATE TABLE patterns (
  id INTEGER PRIMARY KEY NOT NULL,
  item_id bigint,
  lower bigint NOT NULL,
  upper bigint NOT NULL,
  comment text,
  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE NO ACTION ON UPDATE NO ACTION
);

CREATE INDEX patterns_idx_item_id ON patterns (item_id);

CREATE UNIQUE INDEX patterns_lower_upper_key ON patterns (lower, upper);

--
-- Table: schwans_products
--
DROP TABLE schwans_products;

CREATE TABLE schwans_products (
  id INTEGER PRIMARY KEY NOT NULL,
  item_id bigint,
  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE NO ACTION ON UPDATE NO ACTION
);

CREATE INDEX schwans_products_idx_item_id ON schwans_products (item_id);

--
-- Table: inventory
--
DROP TABLE inventory;

CREATE TABLE inventory (
  id INTEGER PRIMARY KEY NOT NULL,
  item_id bigint,
  location_id bigint,
  added_at timestamp DEFAULT current_timestamp,
  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE NO ACTION ON UPDATE NO ACTION,
  FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE NO ACTION ON UPDATE NO ACTION
);

CREATE INDEX inventory_idx_item_id ON inventory (item_id);

CREATE INDEX inventory_idx_location_id ON inventory (location_id);

--
-- Table: item_tags
--
DROP TABLE item_tags;

CREATE TABLE item_tags (
  id INTEGER PRIMARY KEY NOT NULL,
  item_id bigint,
  tag_id bigint,
  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE ON UPDATE NO ACTION,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE ON UPDATE NO ACTION
);

CREATE INDEX item_tags_idx_item_id ON item_tags (item_id);

CREATE INDEX item_tags_idx_tag_id ON item_tags (tag_id);

CREATE UNIQUE INDEX idx_43379_sqlite_autoindex_item_tags_1 ON item_tags (item_id, tag_id);

COMMIT;
