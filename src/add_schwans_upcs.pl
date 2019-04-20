#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: add_schwans_upcs.pl
#
#        USAGE: ./add_schwans_upcs.pl  
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
#      CREATED: 04/19/2019 11:42:21 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Modern::Perl;

use Business::UPC;
use Config::YAML;
use Inventory::Schema;
use LWP::Simple qw(get);
use DBI;

my $schwans_prefix = 72180;

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

my $schwans = $schema->resultset('SchwansProduct');

foreach my $schwan ($schwans->all) {
  my $upc = Business::UPC->new($schwans_prefix.$schwan->id.0);
  $upc->fix_check_digit;

  my $gtin = $schema->resultset('Gtin')->find_or_create(
    {
      gtin => $upc->as_upc,
    }
  );
  $gtin->update(
    {
      item_id => $schwan->item_id,
    }
  );
  print "Schwan's product id: ", $schwan->id, " UPC: ", $upc->as_upc, "\n";
}
