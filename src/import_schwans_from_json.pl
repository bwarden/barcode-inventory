#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: import_schwans_from_json.pl
#
#        USAGE: ./import_schwans_from_json.pl  
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
#      CREATED: 04/24/2019 03:46:11 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;

binmode STDOUT, ':utf8';

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Modern::Perl;

use Config::YAML;
use Data::Dumper;
use Data::Search;
use Inventory::Schema;
use JSON;
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

CAT:
while (my $cat = decode_json(<>)) {
  my @cat_prod = datasearch(
    data => $cat,
    search => 'keys',
    find => 'mpn',
    return => 'hashcontainer',
  ) or next CAT;

  ITEM:
  foreach my $cat_prod (@cat_prod) {
    if ($cat_prod->{webshopIdentifier} && $cat_prod->{title}) {
      my $code = $cat_prod->{webshopIdentifier};
      my $order_num = $cat_prod->{mpn} || '';
      my $brand = ((split(' ', ($cat_prod->{brand}||'Schwans'))))[0];
      my $short_desc = $cat_prod->{title};
      my @description;
      push(@description, $brand, $cat_prod->{title});
      if ($order_num) {
        push(@description, "#$order_num");
      }
      if ($code) {
        push(@description, "id:$code");
      }
      my $description = join(' ', @description);

      print "$code|$short_desc|$description\n";

      my $item;
      my $item_id;

      if ($code =~ /^\d{5}$/) {
        my $product = $schema->resultset('SchwansProduct')->find_or_create(
          {
            id => $code,
          },
        ) or next ITEM;
        if (! $product->item_id) {
          warn "Creating Schwans item $description";
          $item = $schema->resultset('Item')->create(
            {
              short_description => $short_desc,
              description => $description,
            },
          );
          $item_id = $item->id;
          $product->update(
            {
              item_id => $item_id,
            },
          );
        }
        else {
          $item = $schema->resultset('Item')->find(
            {
              id => $product->item_id,
            }
          );
          $item_id = $item->id;
          print "Updating $item_id $description\n";
          $item->update(
            {
              short_description => $short_desc,
              description => $description,
            },
          );
        }
      }
    }
  }
}

exit;

