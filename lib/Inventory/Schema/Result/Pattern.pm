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

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<patterns>

=cut

__PACKAGE__->table("patterns");

=head1 ACCESSORS

=head2 id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'patterns_id_seq'

=head2 item_id

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 1

=head2 lower

  data_type: 'bigint'
  is_nullable: 0

=head2 upper

  data_type: 'bigint'
  is_nullable: 0

=head2 comment

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "patterns_id_seq",
  },
  "item_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 1 },
  "lower",
  { data_type => "bigint", is_nullable => 0 },
  "upper",
  { data_type => "bigint", is_nullable => 0 },
  "comment",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<patterns_lower_upper_key>

=over 4

=item * L</lower>

=item * L</upper>

=back

=cut

__PACKAGE__->add_unique_constraint("patterns_lower_upper_key", ["lower", "upper"]);

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


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2020-04-14 21:48:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:PMmL6KqBGTFTcvm7mrBrOA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
