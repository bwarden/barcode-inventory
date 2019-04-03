use utf8;
package Inventory::Schema::Result::Tag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Inventory::Schema::Result::Tag

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<tags>

=cut

__PACKAGE__->table("tags");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 tag

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "tag",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<tag_unique>

=over 4

=item * L</tag>

=back

=cut

__PACKAGE__->add_unique_constraint("tag_unique", ["tag"]);

=head1 RELATIONS

=head2 item_tags

Type: has_many

Related object: L<Inventory::Schema::Result::ItemTag>

=cut

__PACKAGE__->has_many(
  "item_tags",
  "Inventory::Schema::Result::ItemTag",
  { "foreign.tag_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2019-04-03 15:25:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HsxHuwYxPE9ter4dd2xYIg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
