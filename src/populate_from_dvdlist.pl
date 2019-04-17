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

# Connect to database
my $schema = Inventory::Schema->connect($dbd);

# Commit config changes
$c->write;

my $empty_items = $schema->resultset('Item')->search(
  {
    description => undef,
  },
  {
      order_by => {
        -desc => 'id',
      },
  }
);

my $category = $schema->resultset('Category')->single(
  {
    name => 'movies',
  },
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
      my $gtin_str = $gtin->gtin;

      my $desc = $lookups{$gtin_str}
        and next GTIN; # already done

      print "Looking up $gtin_str\n";

      if (!$desc) {
        # Check DVD CSV database
        my $dvds = $schema->resultset('DvdCsv')->search(
          {
            upc => {
              -like => "\%$gtin_str",
            },
          }
        );

        foreach my $dvd ($dvds->all) {
          $desc = $dvd->dvd_title;
          print "Found $gtin_str in DVD database: $desc\n";
        }
      }

      if ($desc) {
        # Store the new data
        print "Updating item ", $item->id, " to ", $desc, "\n";
        my ($short_desc) = ($desc =~ m/^([^\.,\(:]+)/);

        $item->category($category);
        $item->update(
          {
            description => $desc,
            short_description => $short_desc,
          }
        );
      }
    }
  }
}
