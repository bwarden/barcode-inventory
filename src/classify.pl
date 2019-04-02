#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: classify.pl
#
#        USAGE: ./classify.pl  
#
#  DESCRIPTION: Scan database for barcodes and classify them if type is known
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Brett T. Warden (btw), bwarden@wgz.com
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 04/01/2019 03:48:22 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;

use Business::Barcode::EAN13 qw(valid_barcode);
use Business::ISBN;
use Business::UPC;
use DBI;
use FindBin qw($Bin);

my $db = "$Bin/../data/inventory.db";

my $dbh = DBI->connect("dbi:SQLite:dbname=$db", '', '')
  or die "Couldn't open DB $db\n";

$dbh->sqlite_enable_load_extension(1)
  or die "Couldn't enable extension loading";
$dbh->sqlite_load_extension('/usr/lib/sqlite3/pcre.so')
  or die "Couldn't load SQLite REGEXP engine";

# $dbh->do('CREATE TABLE IF NOT EXISTS code_types(id INTEGER PRIMARY KEY, type TEXT, UNIQUE(type) ON CONFLICT IGNORE);');
# $dbh->do('CREATE TABLE IF NOT EXISTS codes(id INTEGER PRIMARY KEY, code TEXT, code_type INTEGER, parent INTEGER, UNIQUE(code) ON CONFLICT IGNORE, FOREIGN KEY(code_type) REFERENCES code_types(id), FOREIGN KEY(parent) REFERENCES codes(id));');
# $dbh->do('CREATE TRIGGER add_code BEFORE INSERT ON codes FOR EACH ROW BEGIN INSERT INTO code_types (type) VALUES(new.type); END;');

my $scan_sql = q(SELECT code FROM scans WHERE NOT claimed AND (LENGTH(code)=12 OR LENGTH(code)=8 OR LENGTH(code)=13) AND code REGEXP '^\d+$';);
my $store_sql = q(INSERT INTO codes (code, code_type, parent) VALUES(?, (SELECT id FROM code_types WHERE type=? LIMIT 1), (SELECT id FROM codes WHERE code=? LIMIT 1)););
my $claim_sql = q(UPDATE scans SET claimed=1 WHERE code=?);

my $scan_sth = $dbh->prepare($scan_sql)
  or die $dbh->errstr." while preparing ".$scan_sql;
my $store_sth = $dbh->prepare($store_sql)
  or die $dbh->errstr." while preparing ".$store_sql;
my $claim_sth = $dbh->prepare($claim_sql)
  or die $dbh->errstr." while preparing ".$claim_sql;

$scan_sth->execute
  or die $scan_sth->errstr." while executing ".$scan_sql;

CODE:
while (my $scan = $scan_sth->fetchrow_hashref) {
  my $code = $scan->{code};
  if (length($code) == 12) {
    # Maybe UPC-A
    if (my $upc = Business::UPC->new($code)) {
      if ($upc->is_valid) {
        $store_sth->execute($code, 'UPC-A', '')
          or die $store_sth->errstr." while executing ".$scan_sql;
        $claim_sth->execute($code)
          or die $claim_sth->errstr." while executing ".$claim_sql;
        print "UPC-A: ", $code, " -> ", $upc->as_upc, "\n";
        next CODE;
      }
    }
  }
  elsif (length($code) == 13) {
    # Maybe EAN-13 OR ISBN
    my $isbn = Business::ISBN->new($code);
    if ($isbn && $isbn->is_valid) {
      $store_sth->execute($code, 'ISBN-13', '')
        or die $store_sth->errstr." while executing ".$scan_sql;
      $claim_sth->execute($code)
        or die $claim_sth->errstr." while executing ".$claim_sql;
      print "ISBN: ", $code, " -> ", $isbn->as_string, "\n";
      next CODE;
    }
    elsif (my $ean = valid_barcode($code)) {
      $store_sth->execute($code, 'EAN-13', '')
        or die $store_sth->errstr." while executing ".$scan_sql;
      $claim_sth->execute($code)
        or die $claim_sth->errstr." while executing ".$claim_sql;
      print "EAN-13: ", $code, "\n";
      next CODE;
    }
  }
  elsif (length($code) == 8) {
    # Maybe UPC-E OR EAN-8
    if (my $upc = Business::UPC->type_e($code)) {
      $store_sth->execute($upc->as_upc, 'UPC-A', '')
        or die $store_sth->errstr." while executing ".$scan_sql;
      $store_sth->execute($code, 'UPC-E', $upc->as_upc)
        or die $store_sth->errstr." while executing ".$scan_sql;
      $claim_sth->execute($code)
        or die $claim_sth->errstr." while executing ".$claim_sql;
      print "UPC-E: ", $code, " -> ", $upc->as_upc, "\n";
      next CODE;
    }
  }
  print "UNKNOWN: $code\n";
}

