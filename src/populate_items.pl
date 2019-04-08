#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: populate_items.pl
#
#        USAGE: ./populate_items.pl  
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
#      CREATED: 04/08/2019 10:54:32 AM
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

my $CONFIG_FILE = "$Bin/../config";

my $c = Config::YAML->new(
  config => ${CONFIG_FILE},
  output => ${CONFIG_FILE},
);

my $db = "$Bin/../data/inventory.db";
my $dbd = $c->get_dbd || "dbi:SQLite:${db}";
$c->set_dbd($dbd);

my $api_key = $c->get_upsdatabase_org_api_key
  or die "Must configure database key in ${CONFIG_FILE}\n";
my $base_url = 'https://api.upcdatabase.org';

my %lookups;

# Connect to database
my $schema = Inventory::Schema->connect($dbd);

# Commit config changes
$c->write;

my $empty_items = $schema->resultset('Item')->search(
  {
    desc => undef,
  }
);

ITEM:
foreach my $item ($empty_items->all) {
  if (my $gtins = $schema->resultset('Gtin')->search(
      {
        item_id => $item->id,
      }
    )) {

    GTIN:
    foreach my $gtin ($gtins->all) {
      if (!$lookups{$gtin}) {
        my $url = join('/', $base_url, 'product', sprintf("%013d", $gtin->gtin), $api_key);
        my $response = get($url)
          or next GTIN;
        my $data = decode_json($response);
        $lookups{$gtin} = $data;

        if ($data) {
          # Store the new data
          print "Updating item ", $item->id, " to ", $data->{description}, "\n";
          $item->update(
            {
              desc => $data->{description},
            }
          );
        }
      }
    }
  }
}
