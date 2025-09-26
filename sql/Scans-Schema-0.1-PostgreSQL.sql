--
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Fri Sep 26 12:02:03 2025
--
--
-- Table: scans
--
DROP TABLE scans CASCADE;
CREATE TABLE scans (
  id bigserial NOT NULL,
  code text,
  source bigint,
  claimed boolean DEFAULT false,
  date_added timestamp with time zone DEFAULT current_timestamp,
  PRIMARY KEY (id)
);

