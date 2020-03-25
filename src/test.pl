#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: test.pl
#
#        USAGE: ./test.pl  
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
#      CREATED: 03/21/2019 10:29:25 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;

use Modern::Perl;

use Config::YAML;
use DBI;
use FindBin qw($Bin);
use IO::Select;
use Linux::USBKeyboard;

my $CONFIG_FILE = "$Bin/../config";

my $c = Config::YAML->new(
  config => ${CONFIG_FILE},
  output => ${CONFIG_FILE},
);

my $db = "barcode_scans";
my $dbd = $c->get_scans_dbd || "dbi:Pg:dbname=${db}";
$c->set_scans_dbd($dbd);

my $vendor_id  = 0x0581;
my $product_id = 0x0103;
 
my @bpid = (0x0581, 0x0103); # barcode reader

my $dbh = DBI->connect("dbi:Pg:dbname=$db", '', '')
  or die "Couldn't open DB $db\n";

# Commit config changes
$c->write;

my $sth = $dbh->prepare('INSERT INTO scans (code, source) VALUES(?, ?);')
  or die $dbh->errstr;
 
my $bp = Linux::USBKeyboard->open(@bpid)
  or die "Couldn't grab device @bpid\n";

my $sel = IO::Select->new;
$sel->add($bp);
 
my %buffer;
while(my @ready = $sel->can_read) {
  #warn "ready count: ", scalar(@ready);
  foreach my $fh (@ready) {
    my $v;
    if(1 && $fh == $bp) { # treat linewise
      chomp($v = <$fh>);
      print $fh->pid, ' says: ', $v, "\n";
      $sth->execute($v, $fh->pid)
        or die $sth->errstr;
    }
    else { # charwise
      $v = getc($fh);
      if ($v ne "\n") {
        push(@{$buffer{$fh->pid}}, $v);
      }
      else
      {
        if ($buffer{$fh->pid} and ref $buffer{$fh->pid} eq 'ARRAY') {
          local $| = 1;
          my $code = join('', @{$buffer{$fh->pid}});
          print $fh->pid, ' says: ', $code, "\n";
          $sth->execute($code, $fh->pid)
            or die $sth->errstr;
        }
        @{$buffer{$fh->pid}} = ();
      }
    }
  }
}
 
 
# vim:ts=2:sw=2:et:sta
