use utf8;
package Inventory::Schema::Result::Gtin;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Inventory::Schema::Result::Gtin

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<gtins>

=cut

__PACKAGE__->table("gtins");

=head1 ACCESSORS

=head2 gtin

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 item

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "gtin",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "item",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</gtin>

=back

=cut

__PACKAGE__->set_primary_key("gtin");

=head1 RELATIONS

=head2 item

Type: belongs_to

Related object: L<Inventory::Schema::Result::Item>

=cut

__PACKAGE__->belongs_to(
  "item",
  "Inventory::Schema::Result::Item",
  { id => "item" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2019-04-03 12:10:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:o8ATEsnVnEEGgrnpuJDUJw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
