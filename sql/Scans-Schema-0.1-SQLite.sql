--
-- Created by SQL::Translator::Producer::SQLite
-- Created on Fri Sep 26 12:02:03 2025
--

BEGIN TRANSACTION;

--
-- Table: scans
--
DROP TABLE scans;

CREATE TABLE scans (
  id INTEGER PRIMARY KEY NOT NULL,
  code text,
  source bigint,
  claimed boolean DEFAULT false,
  date_added timestamp with time zone DEFAULT current_timestamp
);

COMMIT;
