use utf8;
package Inventory::Schema::Result::Scan;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Inventory::Schema::Result::Scan

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<scans>

=cut

__PACKAGE__->table("scans");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 code

  data_type: 'text'
  is_nullable: 1

=head2 source

  data_type: 'integer'
  is_nullable: 1

=head2 claimed

  data_type: 'boolean'
  default_value: 0
  is_nullable: 0

=head2 date_added

  data_type: 'datetime'
  default_value: current_timestamp
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "code",
  { data_type => "text", is_nullable => 1 },
  "source",
  { data_type => "integer", is_nullable => 1 },
  "claimed",
  { data_type => "boolean", default_value => 0, is_nullable => 0 },
  "date_added",
  {
    data_type     => "datetime",
    default_value => \"current_timestamp",
    is_nullable   => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2019-04-03 15:25:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3XoT/OjDUNKy7cefw4AzWg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
