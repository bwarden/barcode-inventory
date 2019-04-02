use utf8;
package Inventory::Schema::Result::Location;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Inventory::Schema::Result::Location

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<locations>

=cut

__PACKAGE__->table("locations");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 short_name

  data_type: 'text'
  is_nullable: 1

=head2 full_name

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
  "short_name",
  { data_type => "text", is_nullable => 1 },
  "full_name",
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

=head1 UNIQUE CONSTRAINTS

=head2 C<full_name_unique>

=over 4

=item * L</full_name>

=back

=cut

__PACKAGE__->add_unique_constraint("full_name_unique", ["full_name"]);

=head2 C<short_name_unique>

=over 4

=item * L</short_name>

=back

=cut

__PACKAGE__->add_unique_constraint("short_name_unique", ["short_name"]);

=head1 RELATIONS

=head2 inventories

Type: has_many

Related object: L<Inventory::Schema::Result::Inventory>

=cut

__PACKAGE__->has_many(
  "inventories",
  "Inventory::Schema::Result::Inventory",
  { "foreign.location" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 locations

Type: has_many

Related object: L<Inventory::Schema::Result::Location>

=cut

__PACKAGE__->has_many(
  "locations",
  "Inventory::Schema::Result::Location",
  { "foreign.parent" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 parent

Type: belongs_to

Related object: L<Inventory::Schema::Result::Location>

=cut

__PACKAGE__->belongs_to(
  "parent",
  "Inventory::Schema::Result::Location",
  { id => "parent" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2019-04-01 22:30:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Hk2Ip8koEu8k3XSqWcVioA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
