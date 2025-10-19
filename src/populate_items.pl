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
use DBI;

my $CONFIG_FILE = "$Bin/../config";

my $c = Config::YAML->new(
  config => ${CONFIG_FILE},
  output => ${CONFIG_FILE},
);

my $db = "inventory";
my $dbd = $c->get_dbd || "dbi:Pg:dbname=${db}";
$c->set_dbd($dbd);

my $bfpd_dir = $c->get_bfpd_dir || "$Bin/../data/BFPD";
my $bfpd_dbh;
my $bfpd_sth;
if ($bfpd_dir && -d $bfpd_dir) {
  $c->set_bfpd_dir($bfpd_dir);
  $bfpd_dbh = DBI->connect("dbi:CSV:", undef, undef, {
      f_schema => undef,
      f_ext => '.csv/r',
      f_dir => $bfpd_dir,
    }
  ) or die DBI::errstr;
  $bfpd_sth = $bfpd_dbh->prepare('SELECT * FROM Products WHERE gtin_upc=? LIMIT 1;')
    or die $bfpd_dbh->errstr;
}

# Commit config changes
$c->write;

my $api_key = $c->get_upsdatabase_org_api_key
  or die "Must configure database key in ${CONFIG_FILE}\n";
my $upcdb_base_url = 'https://api.upcdatabase.org';

my %lookups;

# Connect to database
my $schema = Inventory::Schema->connect($dbd);

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

      if (!$desc && $bfpd_sth) {
        # Try local copy of BFPD
        $bfpd_sth->execute($gtin_str)
          or die $bfpd_sth->errstr;

        while (my $row = $bfpd_sth->fetchrow_hashref) {
          $desc = $row->{'long_name'};
          print "Found $gtin_str in BFPD: $desc\n";
        }
      }

      UPCDATABASE:
      {
        if (!$desc) {
          # Try upcdatabase.org
          my $url = join('/', $upcdb_base_url, 'product', $gtin_str, $api_key);
          my $response = get($url)
            or last UPCDATABASE;
          my $data = decode_json($response);
          $desc = $data->{'description'} || $data->{'title'}
            and print "Found $gtin_str in upcdatabase.org: $desc\n";
        }
      }

      UPCITEMDB:
      {
        if (!$desc) {
          # Try upcitemdb.com
          my $url = "https://api.upcitemdb.com/prod/trial/lookup?upc=$gtin_str";
          my $response = get($url)
            or last UPCITEMDB;
          my $data = decode_json($response);
          if ($data && $data->{'items'} && ref $data->{'items'} eq 'ARRAY') {
            $desc = $data->{'items'}[0]{'title'}
              and print "Found $gtin_str in upcitemdb.com: $desc\n";
          }
        }
      }

      OPENFOODFACTS:
      {
        if (!$desc) {
          # Try openfoodfacts.org
          my $url = "https://world.openfoodfacts.org/api/v0/product/${gtin_str}.json";
          my $response = get($url)
            or last OPENFOODFACTS;
          my $data = decode_json($response);
          if ($data && $data->{'product'}) {
            my $product = $data->{'product'};
            if (ref $product eq 'HASH') {
              $desc = $product->{'product_name_en'}
                and print "Found $gtin_str in openfoodfacts.org: $desc\n";
            }
          }
        }
      }

      if ($desc) {
        # Store the new data
        print "Updating item ", $item->id, " to ", $desc, "\n";
        $item->update(
          {
            description => $desc,
            short_description => $desc,
          }
        );
      }
    }
  }
}
