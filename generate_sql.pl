#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: generate_sql.pl
#
#        USAGE: ./generate_sql.pl  
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
#      CREATED: 09/26/2025 11:59:07 AM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Inventory::Schema;
use Scans::Schema;

my $ischema = Inventory::Schema->connect();

$ischema->create_ddl_dir(
  ['SQLite', 'PostgreSQL'],
  '0.1',
  './sql/',
);

my $sschema = Scans::Schema->connect();

$sschema->create_ddl_dir(
  ['SQLite', 'PostgreSQL'],
  '0.1',
  './sql/',
);
