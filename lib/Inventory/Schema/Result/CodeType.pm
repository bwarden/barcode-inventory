use utf8;
package Inventory::Schema::Result::CodeType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Inventory::Schema::Result::CodeType

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<code_types>

=cut

__PACKAGE__->table("code_types");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 type

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "type",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<type_unique>

=over 4

=item * L</type>

=back

=cut

__PACKAGE__->add_unique_constraint("type_unique", ["type"]);

=head1 RELATIONS

=head2 codes

Type: has_many

Related object: L<Inventory::Schema::Result::Code>

=cut

__PACKAGE__->has_many(
  "codes",
  "Inventory::Schema::Result::Code",
  { "foreign.code_type" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2019-04-01 22:30:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:G7WMxHpZ+pmdA/ooVtu3pw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
