use utf8;
package Inventory::Schema::Result::Pattern;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Inventory::Schema::Result::Pattern

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<patterns>

=cut

__PACKAGE__->table("patterns");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 pattern

  data_type: 'text'
  is_nullable: 1

=head2 item_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "pattern",
  { data_type => "text", is_nullable => 1 },
  "item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<pattern_unique>

=over 4

=item * L</pattern>

=back

=cut

__PACKAGE__->add_unique_constraint("pattern_unique", ["pattern"]);

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


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2019-04-14 18:44:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+N0+G2DxDPnPV3cPjMCo/A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
