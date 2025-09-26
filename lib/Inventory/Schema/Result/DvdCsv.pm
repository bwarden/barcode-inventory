use utf8;
package Inventory::Schema::Result::DvdCsv;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Inventory::Schema::Result::DvdCsv

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<dvd_csv>

=cut

__PACKAGE__->table("dvd_csv");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'dvd_csv_id_seq'

=head2 dvd_title

  data_type: 'text'
  is_nullable: 1

=head2 studio

  data_type: 'text'
  is_nullable: 1

=head2 released

  data_type: 'date'
  is_nullable: 1

=head2 status

  data_type: 'text'
  is_nullable: 1

=head2 sound

  data_type: 'text'
  is_nullable: 1

=head2 versions

  data_type: 'text'
  is_nullable: 1

=head2 price

  data_type: 'money'
  is_nullable: 1

=head2 rating

  data_type: 'text'
  is_nullable: 1

=head2 year

  data_type: 'text'
  is_nullable: 1

=head2 genre

  data_type: 'text'
  is_nullable: 1

=head2 aspect

  data_type: 'text'
  is_nullable: 1

=head2 upc

  data_type: 'text'
  is_nullable: 1

=head2 dvd_releasedate

  data_type: 'date'
  is_nullable: 1

=head2 timestamp

  data_type: 'timestamp'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dvd_csv_id_seq",
  },
  "dvd_title",
  { data_type => "text", is_nullable => 1 },
  "studio",
  { data_type => "text", is_nullable => 1 },
  "released",
  { data_type => "date", is_nullable => 1 },
  "status",
  { data_type => "text", is_nullable => 1 },
  "sound",
  { data_type => "text", is_nullable => 1 },
  "versions",
  { data_type => "text", is_nullable => 1 },
  "price",
  { data_type => "money", is_nullable => 1 },
  "rating",
  { data_type => "text", is_nullable => 1 },
  "year",
  { data_type => "text", is_nullable => 1 },
  "genre",
  { data_type => "text", is_nullable => 1 },
  "aspect",
  { data_type => "text", is_nullable => 1 },
  "upc",
  { data_type => "text", is_nullable => 1 },
  "dvd_releasedate",
  { data_type => "date", is_nullable => 1 },
  "timestamp",
  { data_type => "timestamp", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2025-09-26 11:48:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aIORxGIdq5rVEPREPmVDqQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
