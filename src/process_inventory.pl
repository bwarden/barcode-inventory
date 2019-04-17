#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: process_inventory.pl
#
#        USAGE: ./process_inventory.pl  
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
#      CREATED: 04/03/2019 12:11:46 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Business::Barcode::EAN13 qw(valid_barcode);
use Business::ISBN;
use Business::UPC;
use Config::YAML;
use DateTime;

use Inventory::Schema;
use Scans::Schema;

my $TIMEOUT = 300; # Inventory scanning is good for 5 minutes

my $CONFIG_FILE = "$Bin/../config";

my $c = Config::YAML->new(
  config => ${CONFIG_FILE},
  output => ${CONFIG_FILE},
);

my $db = "inventory";
my $dbd = $c->get_dbd || "dbi:Pg:dbname=${db}";
$c->set_dbd($dbd);

my $scans_db = "barcode_scans";
my $scans_dbd = $c->get_scans_dbd || "dbi:Pg:dbname=${db}";
$c->set_scans_dbd($scans_dbd);

# Connect to database
my $schema = Inventory::Schema->connect($dbd);
my $scans_schema = Scans::Schema->connect($scans_dbd);

# Commit config changes
$c->write;

# instantiate a datetime parser
my $parser = $schema->storage->datetime_parser;

my $inittime  = DateTime->from_epoch(epoch => 0);
my $endtime   = $inittime->clone->add(seconds => $TIMEOUT);
my $lastrowid = 0;

my $location;
my $operation;

# Fetch entries within the given time
while(my $scans =
  $scans_schema->resultset('Scan')->search(
    {
      claimed => 0,
      id => {
        '>' => $lastrowid,
      },
    }
  )) {

  if (! $scans->count) {
    # Wait for update
    print STDERR ".";
    sleep 5;
  }
  else
  {
    SCAN:
    foreach my $scan ($scans->all) {
      if ($location && DateTime->compare($parser->parse_datetime($scan->date_added), $endtime) > 0) {
        warn "Expired inventory operation at ".$scan->date_added;
        $location = '';
        $operation = '';
      }

      # Check for an inventory command URI
      if ($scan->code =~ m|^inventory://([^/]*)(?:/([^/]*))?|) {
        $location = $1;
        $operation = $2;

        # Mark scan as claimed
        $scan->update(
          {
            claimed => 1,
          });

        if ($location && $operation) {
          warn "Starting $location $operation at ".$scan->date_added;
        }
        else {
          warn "Ended inventory operation at ".$scan->date_added;
        }
      }
      else {

        my $item;
        my $item_id;
        # Iff we're in a valid location/operation, process barcodes
        if ($location && $operation) {
          if (my $code = get_validated_gtin($scan->code)) {

            # Check for a UPC pattern
            my $pattern = $schema->resultset('Pattern')->search(
              {
                upper => {
                  '>=' => $code,
                },
                lower => {
                  '<=' => $code,
                },
              },
              {
                  order_by => { -asc => 'upper - lower' },
                  rows => 1,
              },
            );
            if ($pattern && $pattern->count) {
              foreach my $match ($pattern->all) {
                unless ($item = $match->item) {
                  warn "Discarding by pattern: $code\n";
                  $lastrowid = $scan->id;
                  next SCAN; # Pattern indicates to discard this one
                }
                $item_id = $item->id;
              }
            }

            if (! $item_id) {
              # Store GTIN
              my $gtin = $schema->resultset('Gtin')->find_or_create(
                {
                  gtin => $code,
                });

              # Add/link item
              if (! $gtin->item_id) {
                warn "Creating item for $code";
                $item = $schema->resultset('Item')->find_or_create(
                  {
                    short_description => $code,
                  },
                  {
                    rows => 1,
                  });
                $item_id = $item->id;
                $gtin->update(
                  {
                    item_id => $item_id,
                  });
              }
              else {
                $item_id = $gtin->item_id;
                $item = $schema->resultset('Item')->find(
                  {
                    id => $item_id,
                  },
                  {
                    rows => 1,
                  });
              }
            }

            # Add/remove item to/from location
            if (my $loc = $schema->resultset('Location')->find(
                {
                  short_name => $location,
                }
              )) {

              if ($operation eq 'add') {
                my $inventory = $schema->resultset('Inventory')->create(
                  {
                    item_id => $item_id,
                    location_id => $loc->id,
                  });
                print "Added to       ", $loc->full_name, ": ",
                $item->short_desc, "\n";
              }

              if ($operation eq 'delete' || $operation eq 'remove') {
                if (my $inventory = $schema->resultset('Inventory')->find(
                    {
                      item_id => $item_id,
                      location_id => $loc->id,
                    },
                    {
                      rows => 1,
                    },
                  )) {
                  $inventory->delete;
                  print "Removed from ", $loc->full_name, ": ",
                  $item->short_desc, "\n";
                }
                else {
                  warn "No more ".$item->short_desc." in ".$loc->full_name;
                }
              }
            }

            # Mark scan as claimed
            $scan->update(
              {
                claimed => 1,
              });
          }
        }
      }

      # Bump the time interval so we a) don't reconsider things we've already
      # tried, and b) allow new codes to push us along
      $lastrowid = $scan->id;
      $inittime = $parser->parse_datetime($scan->date_added);
      $endtime  = $inittime->clone->add(seconds => $TIMEOUT);
    }
    sleep 1;
  }
}



exit;


sub get_validated_gtin {
  my ($code) = shift || return;

  if (length($code) == 12) {
    # Maybe UPC-A
    if (my $upc = Business::UPC->new($code)) {
      if ($upc->is_valid) {
        return 1 * $upc->as_upc;
      }
    }
  }
  elsif (length($code) == 13) {
    # Maybe EAN-13 OR ISBN
    my $isbn = Business::ISBN->new($code);
    if ($isbn && $isbn->is_valid) {
      return 1 * join('', split(/-/, $isbn->as_string));
    }
    elsif (my $ean = valid_barcode($code)) {
      return 1 * $code;
    }
  }
  elsif (length($code) == 8) {
    # Maybe UPC-E OR EAN-8
    if (my $upc = Business::UPC->type_e($code)) {
      return 1 * $upc->as_upc;
    }
  }
}
