use utf8;
package Inventory::Schema::Result::Category;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Inventory::Schema::Result::Category

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<categories>

=cut

__PACKAGE__->table("categories");

=head1 ACCESSORS

=head2 id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'categories_id_seq'

=head2 name

  data_type: 'citext'
  is_nullable: 0

=head2 description

  data_type: 'citext'
  is_nullable: 1

=head2 parent_id

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
    sequence          => "categories_id_seq",
  },
  "name",
  { data_type => "citext", is_nullable => 0 },
  "description",
  { data_type => "citext", is_nullable => 1 },
  "parent_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<categories_name_key>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("categories_name_key", ["name"]);

=head1 RELATIONS

=head2 categories

Type: has_many

Related object: L<Inventory::Schema::Result::Category>

=cut

__PACKAGE__->has_many(
  "categories",
  "Inventory::Schema::Result::Category",
  { "foreign.parent_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 items

Type: has_many

Related object: L<Inventory::Schema::Result::Item>

=cut

__PACKAGE__->has_many(
  "items",
  "Inventory::Schema::Result::Item",
  { "foreign.category_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 parent

Type: belongs_to

Related object: L<Inventory::Schema::Result::Category>

=cut

__PACKAGE__->belongs_to(
  "parent",
  "Inventory::Schema::Result::Category",
  { id => "parent_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2025-09-26 11:48:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aKoEXAMMLvIppWuBuGyOGQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
