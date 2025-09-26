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

  data_type: 'bigint'
  is_nullable: 0

=head2 item_id

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 1

=head2 item_quantity

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=head2 id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'gtins_id_seq'

=cut

__PACKAGE__->add_columns(
  "gtin",
  { data_type => "bigint", is_nullable => 0 },
  "item_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 1 },
  "item_quantity",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
  "id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "gtins_id_seq",
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<gtins_gtin_item_id_key>

=over 4

=item * L</gtin>

=item * L</item_id>

=back

=cut

__PACKAGE__->add_unique_constraint("gtins_gtin_item_id_key", ["gtin", "item_id"]);

=head1 RELATIONS

=head2 item

Type: belongs_to

Related object: L<Inventory::Schema::Result::Item>

=cut

__PACKAGE__->belongs_to(
  "item",
  "Inventory::Schema::Result::Item",
  { id => "item_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2025-09-26 11:48:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:VHADns/dmt9mjXagI0nc7w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
