use utf8;
package Inventory::Schema::Result::Item;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Inventory::Schema::Result::Item

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<items>

=cut

__PACKAGE__->table("items");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 short_desc

  data_type: 'text'
  is_nullable: 1

=head2 desc

  data_type: 'text'
  is_nullable: 1

=head2 parent

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "short_desc",
  { data_type => "text", is_nullable => 1 },
  "desc",
  { data_type => "text", is_nullable => 1 },
  "parent",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 codes

Type: has_many

Related object: L<Inventory::Schema::Result::Code>

=cut

__PACKAGE__->has_many(
  "codes",
  "Inventory::Schema::Result::Code",
  { "foreign.item" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 inventories

Type: has_many

Related object: L<Inventory::Schema::Result::Inventory>

=cut

__PACKAGE__->has_many(
  "inventories",
  "Inventory::Schema::Result::Inventory",
  { "foreign.item" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 items

Type: has_many

Related object: L<Inventory::Schema::Result::Item>

=cut

__PACKAGE__->has_many(
  "items",
  "Inventory::Schema::Result::Item",
  { "foreign.parent" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 parent

Type: belongs_to

Related object: L<Inventory::Schema::Result::Item>

=cut

__PACKAGE__->belongs_to(
  "parent",
  "Inventory::Schema::Result::Item",
  { id => "parent" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2019-04-01 22:30:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ag1Z7W75AeY0YN+KGtFq6A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
