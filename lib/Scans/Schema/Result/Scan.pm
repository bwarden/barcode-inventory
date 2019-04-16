use utf8;
package Scans::Schema::Result::Scan;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Scans::Schema::Result::Scan

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<scans>

=cut

__PACKAGE__->table("scans");

=head1 ACCESSORS

=head2 id

  data_type: 'bigint'
  is_nullable: 0

=head2 code

  data_type: 'text'
  is_nullable: 1

=head2 source

  data_type: 'bigint'
  is_nullable: 1

=head2 claimed

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=head2 date_added

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "bigint", is_nullable => 0 },
  "code",
  { data_type => "text", is_nullable => 1 },
  "source",
  { data_type => "bigint", is_nullable => 1 },
  "claimed",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "date_added",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2019-04-16 12:15:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yzN4UagR7wQXkIDJr2Xsuw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
