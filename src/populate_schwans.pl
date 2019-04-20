#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: populate_schwans.pl
#
#        USAGE: ./populate_schwans.pl  
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
#      CREATED: 04/19/2019 11:06:00 PM
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

while (my $line = <>) {
  chomp $line;
  my ($code, $desc) = split(/\t/, $line);

  my $item;
  my $item_id;

  if ($code =~ /^\d{5}$/) {
    my $product = $schema->resultset('SchwansProduct')->find_or_create(
      {
        id => $code,
      },
    ) or next SCAN;
    if (! $product->item_id) {
      warn "Creating Schwans item $code";
      $item = $schema->resultset('Item')->create(
        {
          short_description => "Schwan's $code",
          description => $desc,
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
    }
  } 
}

exit;

