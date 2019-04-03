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
use DateTime;

use Inventory::Schema;

my $TIMEOUT = 300; # Inventory scanning is good for 5 minutes
my $db = "$Bin/../data/inventory.db";
my $dbd = "dbi:SQLite:${db}";

# Connect to database
my $schema = Inventory::Schema->connect($dbd);
my $parser = $schema->storage->datetime_parser;

my $inittime = DateTime->from_epoch(epoch => 0);
my $endtime  = $inittime->add(seconds => $TIMEOUT);

$inittime = $inittime->subtract(days => 1);

print $inittime;
print $endtime;

my $location;
my $operation;

# Fetch entries within the given time
while(my $scans =
  $schema->resultset('Scan')->search(
    {
      claimed => 0,
      date_added => {
        '>=' => $parser->format_datetime($inittime),
        '<'  => ($location && $operation) ? $parser->format_datetime($endtime ) : 'NOW',
      },
    }
  )) {

  if (! $scans->count) {
    # Wait for update
    warn "Waiting for update";
    sleep 5;
  }
  else
  {

    SCAN:
    foreach my $scan ($scans->all) {
      if (DateTime->compare($parser->parse_datetime($scan->date_added), $endtime) > 0) {
        warn "Expired inventory operation at ".$scan->date_added;
        $location = '';
        $operation = '';
      }

      # Check for an inventory command URI
      if ($scan->code =~ m|^inventory://([^/]*)(?:/([^/]*))?|) {
        $location = $1;
        $operation = $2;

        if ($location && $operation) {
          warn "Starting $location $operation at ".$scan->date_added;
        }
        else {
          warn "Ended inventory operation at ".$scan->date_added;
        }
      }
      else {
        # Iff we're in a valid location/operation, process barcodes
        if ($location && $operation) {
          if (my $code = get_validated_gtin($scan->code)) {

            # Store GTIN
            my $gtin = $schema->resultset('Gtin')->find_or_create(
              {
                gtin => $code,
              });

            # Add/link item
            if (! $gtin->item) {
              warn "Creating item for $code";
              my $item = $schema->resultset('Item')->create(
                {
                  desc => $code,
                });
              $gtin->update(
                {
                  item => $item->id,
                });
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
                    item => $gtin->item,
                    location => $loc->id,
                  });
              }

              if ($operation eq 'delete') {
                my $inventory = $schema->resultset('Inventory')->find(
                  {
                    item => $gtin->item,
                    location => $loc->id,
                  });
                $inventory->delete;
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
      $inittime = $parser->parse_datetime($scan->date_added);
      $endtime  = $inittime->add(seconds => $TIMEOUT);
    }
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
