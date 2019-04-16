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

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'item_tags_id_seq'

=head2 short_desc

  data_type: 'text'
  is_nullable: 1

=head2 desc

  data_type: 'text'
  is_nullable: 1

=head2 parent_id

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 1

=head2 category_id

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "item_tags_id_seq",
  },
  "short_desc",
  { data_type => "text", is_nullable => 1 },
  "desc",
  { data_type => "text", is_nullable => 1 },
  "parent_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 1 },
  "category_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 category

Type: belongs_to

Related object: L<Inventory::Schema::Result::Category>

=cut

__PACKAGE__->belongs_to(
  "category",
  "Inventory::Schema::Result::Category",
  { id => "category_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 gtins

Type: has_many

Related object: L<Inventory::Schema::Result::Gtin>

=cut

__PACKAGE__->has_many(
  "gtins",
  "Inventory::Schema::Result::Gtin",
  { "foreign.item_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 inventories

Type: has_many

Related object: L<Inventory::Schema::Result::Inventory>

=cut

__PACKAGE__->has_many(
  "inventories",
  "Inventory::Schema::Result::Inventory",
  { "foreign.item_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 item_tags

Type: has_many

Related object: L<Inventory::Schema::Result::ItemTag>

=cut

__PACKAGE__->has_many(
  "item_tags",
  "Inventory::Schema::Result::ItemTag",
  { "foreign.item_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 items

Type: has_many

Related object: L<Inventory::Schema::Result::Item>

=cut

__PACKAGE__->has_many(
  "items",
  "Inventory::Schema::Result::Item",
  { "foreign.parent_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 parent

Type: belongs_to

Related object: L<Inventory::Schema::Result::Item>

=cut

__PACKAGE__->belongs_to(
  "parent",
  "Inventory::Schema::Result::Item",
  { id => "parent_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 patterns

Type: has_many

Related object: L<Inventory::Schema::Result::Pattern>

=cut

__PACKAGE__->has_many(
  "patterns",
  "Inventory::Schema::Result::Pattern",
  { "foreign.item_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2019-04-16 13:18:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZtXMdqQyNUAAKJVyN/8p/w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
