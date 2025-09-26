use utf8;
package Inventory::Schema::Result::ItemTag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Inventory::Schema::Result::ItemTag

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<item_tags>

=cut

__PACKAGE__->table("item_tags");

=head1 ACCESSORS

=head2 id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'item_tags_id_seq'

=head2 item_id

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 1

=head2 tag_id

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
  "item_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 1 },
  "tag_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<idx_43379_sqlite_autoindex_item_tags_1>

=over 4

=item * L</item_id>

=item * L</tag_id>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "idx_43379_sqlite_autoindex_item_tags_1",
  ["item_id", "tag_id"],
);

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
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);

=head2 tag

Type: belongs_to

Related object: L<Inventory::Schema::Result::Tag>

=cut

__PACKAGE__->belongs_to(
  "tag",
  "Inventory::Schema::Result::Tag",
  { id => "tag_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2025-09-26 11:48:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:M1XJm5JOn0uq5QYmgd8nEg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
