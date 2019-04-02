use utf8;
package Inventory::Schema::Result::Code;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Inventory::Schema::Result::Code

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<codes>

=cut

__PACKAGE__->table("codes");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 code

  data_type: 'text'
  is_nullable: 1

=head2 code_type

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 parent

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 item

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "code",
  { data_type => "text", is_nullable => 1 },
  "code_type",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "parent",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "item",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<code_unique>

=over 4

=item * L</code>

=back

=cut

__PACKAGE__->add_unique_constraint("code_unique", ["code"]);

=head1 RELATIONS

=head2 code_type

Type: belongs_to

Related object: L<Inventory::Schema::Result::CodeType>

=cut

__PACKAGE__->belongs_to(
  "code_type",
  "Inventory::Schema::Result::CodeType",
  { id => "code_type" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 codes

Type: has_many

Related object: L<Inventory::Schema::Result::Code>

=cut

__PACKAGE__->has_many(
  "codes",
  "Inventory::Schema::Result::Code",
  { "foreign.parent" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

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

=head2 parent

Type: belongs_to

Related object: L<Inventory::Schema::Result::Code>

=cut

__PACKAGE__->belongs_to(
  "parent",
  "Inventory::Schema::Result::Code",
  { id => "parent" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2019-04-01 22:30:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:q8QT9YC1/wV7XRu77VjgmQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
