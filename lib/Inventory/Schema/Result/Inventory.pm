use utf8;
package Inventory::Schema::Result::Inventory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Inventory::Schema::Result::Inventory

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<inventory>

=cut

__PACKAGE__->table("inventory");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 item

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 location

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "item",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "location",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

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

=head2 location

Type: belongs_to

Related object: L<Inventory::Schema::Result::Location>

=cut

__PACKAGE__->belongs_to(
  "location",
  "Inventory::Schema::Result::Location",
  { id => "location" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2019-04-01 22:30:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5F8UmbwgFH2qjgf3ILGa6A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
