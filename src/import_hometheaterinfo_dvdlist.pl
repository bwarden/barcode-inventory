#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: import_hometheaterinfo_dvdlist.pl
#
#        USAGE: ./import_hometheaterinfo_dvdlist.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Brett T. Warden (btw), bwarden@wgz.com
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 04/16/2019 09:41:29 AM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Modern::Perl;

use Config::YAML;
use Inventory::Schema;
use JSON qw(decode_json);
use LWP::Simple qw(get);
use DBI;

my $CONFIG_FILE = "$Bin/../config";

my $c = Config::YAML->new(
  config => ${CONFIG_FILE},
  output => ${CONFIG_FILE},
);

my $db = "inventory";
my $dbd = $c->get_dbd || "dbi:Pg:dbname=${db}";
$c->set_dbd($dbd);

my $dvddb_dir = $c->get_dvddb_dir || "$Bin/../data/dvd_csv";
if ($dvddb_dir && -d $dvddb_dir) {
  $c->set_dvddb_dir($dvddb_dir);
}

my $dvd_dbh = DBI->connect("dbi:CSV:", undef, undef, {
    f_schema => undef,
    f_ext => '.txt/r',
    f_dir => $dvddb_dir,
  }
) or die DBI::errstr;
my $dvd_sth = $dvd_dbh->prepare('SELECT * FROM dvd_csv WHERE upc LIKE ?;')
  or die $dvd_dbh->errstr;

# Commit config changes
$c->write;

# Connect to database
my $schema = Inventory::Schema->connect($dbd);

my $empty_items = $schema->resultset('Item')->search(
  {
    desc => undef,
  }
);

my %lookups;

ITEM:
foreach my $item ($empty_items->all) {
  if (my $gtins = $schema->resultset('Gtin')->search(
      {
        item_id => $item->id,
      }
    )) {

    GTIN:
    foreach my $gtin ($gtins->all) {
      my $gtin_str = sprintf("%013d", $gtin->gtin);

      my $desc = $lookups{$gtin_str}
        and next GTIN; # already done

      print "Looking up $gtin_str\n";

      if (!$desc && $dvd_sth) {
        # Try local copy of BFPD
        $dvd_sth->execute("\%$gtin_str")
          or die $dvd_sth->errstr;

        while (my $row = $dvd_sth->fetchrow_hashref) {
          $desc = $row->{'dvd_title'};
          print "Found $gtin_str in DVD database: $desc\n";
        }
      }

      if ($desc) {
        # Store the new data
        print "Updating item ", $item->id, " to ", $desc, "\n";
        my ($short_desc) = ($desc =~ m/(.*)\(/);
        $item->update(
          {
            desc => $desc,
            short_desc => $short_desc,
          }
        );
      }
    }
  }
}
