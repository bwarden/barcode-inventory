#!/usr/bin/env perl
use Mojolicious::Lite -signatures;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Config::YAML;
use Inventory::Schema;
use Scans::Schema;
use Mojo::ByteStream;
use SVG::Barcode::Code128;
use SVG::Barcode::EAN8;
use SVG::Barcode::EAN13; # Renders EAN13
use SVG::Barcode::UPCA;
use SVG::Barcode::UPCE;
use SVG::Barcode::QRCode;
use Business::UPC;
use Business::ISBN;
use Business::Barcode::EAN13 qw(valid_barcode); # Validates EAN13
use HTTP::Date qw(time2str);

# --- Configuration and Database Connection ---

# --- Application Startup ---
app->hook(before_server_start => sub {
    my $file = "$Bin/../config";
    die "Config file not found at $file" unless -f $file;
    my $config = Config::YAML->new(config => $file, output => $file);
    app->log->info("Configuration loaded from $file");

    my $inventory_dsn = $config->get_dbd || 'dbi:Pg:dbname=inventory';
    app->attr(schema => sub {
        eval { Inventory::Schema->connect($inventory_dsn) }
            or die "FATAL: Could not connect to inventory database ($inventory_dsn): $@";
    });

    my $scans_dsn = $config->get_scans_dbd || 'dbi:Pg:dbname=barcode_scans';
    app->attr(scans_schema => sub {
        eval { Scans::Schema->connect($scans_dsn) }
            or die "FATAL: Could not connect to scans database ($scans_dsn): $@";
    });
});

# --- Routes ---

# GET / (Dashboard)
get '/' => sub ($c) {
    # 1. Get all items and their direct inventory counts
    my %direct_counts;
    my $direct_counts_rs = $c->app->schema->resultset('Inventory')->search({}, {
        select   => [ 'item_id', { count => 'item_id' } ],
        as       => [qw/item_id count/],
        group_by => 'item_id',
    });
    while (my $row = $direct_counts_rs->next) {
        $direct_counts{$row->get_column('item_id')} = $row->get_column('count');
    }

    # 1b. Get all locations for each item
    my %item_locations;
    my $inventory_entries = $c->app->schema->resultset('Inventory')->search(
        {},
        { prefetch => 'location' }
    );
    while (my $entry = $inventory_entries->next) {
        next unless my $loc = $entry->location;
        $item_locations{$entry->item_id}{$loc->short_name} = 1;
    }

    # 2. Build a tree of all items
    my %items;
    my %children_of;
    my $all_items = [ $c->app->schema->resultset('Item')->search({}, { prefetch => ['items', 'gtins'] })->all ];
    for my $item (@$all_items) {
        $items{$item->id} = $item;
        push @{ $children_of{$item->parent_id || 0} }, $item->id;
    }

    # 3. Recursively build the hierarchical summary
    my $build_tree;
    $build_tree = sub {
        my ($parent_id) = @_;
        my @nodes;

        return unless exists $children_of{$parent_id};

        for my $id (sort { lc($items{$a}->short_description) cmp lc($items{$b}->short_description) } @{$children_of{$parent_id}}) {
            my $item = $items{$id};
            my $direct_count = $direct_counts{$id} || 0;
            my @child_nodes = $build_tree->($id);

            # Calculate total count by summing children's totals
            my $total_count = $direct_count;
            $total_count += $_->{total_count} for @child_nodes;

            # Only include nodes that have inventory
            next if $total_count == 0;

            my $locations_str;
            if ($direct_count > 0 && exists $item_locations{$id}) {
                $locations_str = join(', ', sort keys %{ $item_locations{$id} });
            }

            # An item is a "parent" if it has children or no GTINs of its own.
            my $is_parent = $item->items->count > 0 || $item->gtins->count == 0;

            push @nodes, { item => $item, direct_count => $direct_count, total_count => $total_count, children => \@child_nodes, locations => $locations_str, is_parent => $is_parent };
        }
        return @nodes;
    };

    my @inventory_summary = $build_tree->(0);

    my $recent_scans = $c->app->scans_schema->resultset('Scan')->search(
        {},
        {
            order_by => { -desc => 'date_added' },
            rows => 50
        }
    );

    $c->render(
        template          => 'index',
        inventory_summary => \@inventory_summary,
        recent_scans      => $recent_scans
    );
};

# --- Item Management ---

# GET /items
get('/items' => sub ($c) {
    # Build a hierarchical list of all items
    my %items;
    my %children_of;
    my $all_items_list = [ $c->app->schema->resultset('Item')->search({}, { prefetch => ['parent', 'items', 'gtins'] })->all ];
    for my $item (@$all_items_list) {
        $items{$item->id} = $item;
        push @{ $children_of{$item->parent_id || 0} }, $item->id;
    }

    my $build_item_tree;
    $build_item_tree = sub {
        my ($parent_id, $level) = @_;
        my @nodes;
        return unless exists $children_of{$parent_id};

        for my $item_id (sort { lc($items{$a}->short_description) cmp lc($items{$b}->short_description) } @{$children_of{$parent_id}}) {
            my $item_node = $items{$item_id};
            # An item is a "parent" if it has children or no GTINs of its own.
            my $is_parent = $item_node->items->count > 0 || $item_node->gtins->count == 0;
            push @nodes, { item => $item_node, level => $level, is_parent => $is_parent };
            push @nodes, $build_item_tree->($item_id, $level + 1);
        }
        return @nodes;
    };
    my @item_tree = $build_item_tree->(0, 0);

    # Build a hierarchical list of parent items for the dropdown
    my %parent_items_for_dropdown;
    my %parent_children_of;
    for my $item (@$all_items_list) {
        next unless ($item->items->count > 0 || $item->gtins->count == 0);
        $parent_items_for_dropdown{$item->id} = $item;
        push @{ $parent_children_of{$item->parent_id || 0} }, $item->id;
    }
    my $build_parent_tree;
    $build_parent_tree = sub {
        my ($parent_id, $level) = @_;
        my @nodes;
        return unless exists $parent_children_of{$parent_id};
        for my $item_id (sort { lc($parent_items_for_dropdown{$a}->short_description) cmp lc($parent_items_for_dropdown{$b}->short_description) } @{$parent_children_of{$parent_id}}) {
            my $item_node = $parent_items_for_dropdown{$item_id};
            push @nodes, { item => $item_node, level => $level, is_parent => 1 }; # It's a parent by definition
            push @nodes, $build_parent_tree->($item_id, $level + 1);
        }
        return @nodes;
    };
    my @parent_item_list = $build_parent_tree->(0, 0);

    $c->render(template => 'items', item_tree => \@item_tree, parent_item_list => \@parent_item_list);
})->name('items');

# GET /item/:id
get('/item/:id' => sub ($c) {
    my $id = $c->param('id');
    my $item = $c->app->schema->resultset('Item')->find($id, {
        prefetch => ['gtins', 'parent', 'category']
    });
    # Prefetch tags for the item
    $item = $c->app->schema->resultset('Item')->find($id, { prefetch => { 'item_tags' => 'tag' } });
    unless ($item) {
        $c->flash(error => "Item with ID '$id' was not found.");
        return $c->redirect_to('items');
    }

    my $locations_rs = $c->app->schema->resultset('Inventory')->search(
        { item_id => $id },
        {
            select   => [ 'location.id', 'location.full_name', { count => 'location_id' } ],
            as       => [qw/location_id location_name count/],
            join     => 'location',
            group_by => [ 'location.id', 'location.full_name' ],
            order_by => 'location.full_name'
        }
    );

    # Build a hierarchical list of possible parent items for the dropdown
    my %items_for_dropdown;
    my %children_of_for_dropdown;
    my $possible_parents = [ $c->app->schema->resultset('Item')->search({ 'me.id' => { '!=' => $id } }, { prefetch => ['items', 'gtins'] })->all ];
    for my $i (@$possible_parents) {
        $items_for_dropdown{$i->id} = $i;
        push @{ $children_of_for_dropdown{$i->parent_id || 0} }, $i->id;
    }

    my $build_parent_tree;
    $build_parent_tree = sub {
        my ($parent_id, $level) = @_;
        my @nodes;
        return unless exists $children_of_for_dropdown{$parent_id};

        for my $item_id (sort { lc($items_for_dropdown{$a}->short_description) cmp lc($items_for_dropdown{$b}->short_description) } @{$children_of_for_dropdown{$parent_id}}) {
            my $item_node = $items_for_dropdown{$item_id};
            # An item is a "parent" if it has children or no GTINs of its own.
            my $is_parent = $item_node->items->count > 0 || $item_node->gtins->count == 0;
            push @nodes, { item => $item_node, level => $level, is_parent => $is_parent };
            push @nodes, $build_parent_tree->($item_id, $level + 1);
        }
        return @nodes;
    };
    my @parent_item_list = $build_parent_tree->(0, 0);


    # Build a hierarchical list of all locations for the dropdown
    my %locations_for_dropdown;
    my %loc_children_of;
    my $all_locs = [ $c->app->schema->resultset('Location')->all ];
    for my $l (@$all_locs) {
        $locations_for_dropdown{$l->id} = $l;
        push @{ $loc_children_of{$l->parent_id || 0} }, $l->id;
    }
    my $build_loc_tree;
    $build_loc_tree = sub {
        my ($parent_id, $level) = @_;
        my @nodes;
        return unless exists $loc_children_of{$parent_id};
        for my $loc_id (sort { lc($locations_for_dropdown{$a}->short_name) cmp lc($locations_for_dropdown{$b}->short_name) } @{$loc_children_of{$parent_id}}) {
            push @nodes, { location => $locations_for_dropdown{$loc_id}, level => $level };
            push @nodes, $build_loc_tree->($loc_id, $level + 1);
        }
        return @nodes;
    };
    my @all_locations_list = $build_loc_tree->(0, 0);

    # Get all tags for the dropdown
    my $all_tags = [ $c->app->schema->resultset('Tag')->search({}, { order_by => 'tag' })->all ];

    $c->render(
        template => 'item',
        item => $item,
        locations => [ $locations_rs->all ],
        parent_item_list => \@parent_item_list,
        all_locations_list => \@all_locations_list,
        all_tags => $all_tags,
    );
})->name('item_show');

# POST /item/create
post('/item/create' => sub ($c) {
    my $desc = $c->param('short_description');
    my $parent_id = $c->param('parent_id') || undef;

    my $item = $c->app->schema->resultset('Item')->create({
        short_description => $desc,
        parent_id => $parent_id
    });

    $c->flash(message => "Item '$desc' created successfully.");
    $c->redirect_to('items');
})->name('item_create');

# POST /item/:id/update
post '/item/:id/update' => sub ($c) {
    my $id = $c->param('id');
    my $item = $c->app->schema->resultset('Item')->find($id)
        or return $c->reply->not_found;
    return $c->reply->not_found unless $item;

    $item->update({
        short_description => $c->param('short_description'),
        description       => $c->param('description'),
        parent_id         => $c->param('parent_id') || undef,
    });

    $c->flash(message => "Item updated successfully.");
    $c->redirect_to('/item/' . $id);
};

# POST /item/:id/delete
post '/item/:id/delete' => sub ($c) {
    my $id = $c->param('id');
    my $item = $c->app->schema->resultset('Item')->find($id);
    return $c->reply->not_found unless $item;

    # Handle dependencies before deleting
    $c->app->schema->txn_do(sub {
        $item->inventories->delete_all;
        $item->gtins->delete_all;
        $item->item_tags->delete_all;
        # Add other dependencies here (item_tags, etc.)
        $item->delete;
    });

    $c->flash(message => "Item and all associated data deleted.");
    $c->redirect_to('items');
};

# POST /item/:id/add_gtin
post '/item/:id/add_gtin' => sub ($c) {
    my $id = $c->param('id');
    my $gtin_code = $c->param('gtin');
    my $item = $c->app->schema->resultset('Item')->find($id);
    return $c->reply->not_found unless $item;

    eval {
        $item->find_or_create_related('gtins', { gtin => $gtin_code });
        $c->flash(message => "GTIN $gtin_code added.");
    };
    if ($@) {
        $c->flash(error => "Failed to add GTIN. It might be invalid or already exist for another item. ($@)");
    }

    $c->redirect_to('/item/' . $id);
};

# POST /gtin/:id/delete
post '/gtin/:id/delete' => sub ($c) {
    my $id = $c->param('id');
    my $gtin = $c->app->schema->resultset('Gtin')->find($id);
    return $c->reply->not_found unless $gtin;

    my $item_id = $gtin->item_id;
    $gtin->delete;

    $c->flash(message => "GTIN deleted.");
    $c->redirect_to('/item/' . $item_id);
};

# --- Item-Tag Management ---

# POST /item/:id/add_tag
post '/item/:id/add_tag' => sub ($c) {
    my $item_id = $c->param('id');
    my $tag_id = $c->param('tag_id');

    my $item = $c->app->schema->resultset('Item')->find($item_id);
    my $tag = $c->app->schema->resultset('Tag')->find($tag_id);
    return $c->reply->not_found unless $item && $tag;

    eval {
        $item->find_or_create_related('item_tags', { tag_id => $tag_id });
        $c->flash(message => "Tag '" . $tag->tag . "' added to item.");
    };
    if ($@) {
        $c->flash(error => "Failed to add tag: $@");
    }

    $c->redirect_to('/item/' . $item_id);
};

# POST /item_tag/:id/delete
post '/item_tag/:id/delete' => sub ($c) {
    my $item_tag_id = $c->param('id');
    my $item_tag = $c->app->schema->resultset('ItemTag')->find($item_tag_id);
    return $c->reply->not_found unless $item_tag;

    my $item_id = $item_tag->item_id;
    $item_tag->delete;

    $c->flash(message => "Tag removed from item.");
    $c->redirect_to('/item/' . $item_id);
};

# --- Item-Pattern Management ---

# POST /item/:id/add_pattern
post '/item/:id/add_pattern' => sub ($c) {
    my $item_id = $c->param('id');
    my $item = $c->app->schema->resultset('Item')->find($item_id);
    return $c->reply->not_found unless $item;

    eval {
        $item->create_related('patterns', {
            lower   => $c->param('lower'),
            upper   => $c->param('upper'),
            comment => $c->param('comment'),
        });
        $c->flash(message => "Pattern added.");
    };
    if ($@) {
        $c->flash(error => "Failed to add pattern: $@");
    }
    $c->redirect_to('/item/' . $item_id);
};

# POST /gtin/:id/update_quantity
post('/gtin/:id/update_quantity' => sub ($c) {
    my $id = $c->param('id');
    my $quantity = $c->param('quantity');
    my $gtin = $c->app->schema->resultset('Gtin')->find($id);
    return $c->reply->not_found unless $gtin;

    $gtin->update({ item_quantity => $quantity });
    $c->flash(message => "Quantity for GTIN " . $gtin->gtin . " updated to $quantity.");

    if ($c->req->is_xhr) {
        return $c->render(json => { success => 1, message => "Quantity updated to $quantity." });
    } else {
        # Redirect back to the page the user was on
        my $redirect_to = $c->param('redirect_to') || $c->url_for('gtins');
        $c->redirect_to($redirect_to);
    }
})->name('gtin_update_quantity');

# GET /gtins
get('/gtins' => sub ($c) {
    my $gtins_rs = $c->app->schema->resultset('Gtin')->search(
        {},
        {
            order_by => { -asc => 'gtin' },
            prefetch => 'item'
        }
    );
    $c->render(template => 'gtins', gtins => [ $gtins_rs->all ]);
})->name('gtins');

# GET /barcode/*code
get('/barcode/*code' => sub ($c) {
    my $code = $c->param('code');
    my $symbology;

    $c->app->log->debug("Received request for barcode image of '$code'");

    # For numeric codes, determine the most specific valid symbology
    if ($code =~ /^\d+$/) {
        if (length($code) >= 9 && length($code) <= 11) {
            # Handle UPC-A codes stored numerically, which strips leading 0s
            $code = sprintf("%012d", $code);
        }

        if (length($code) == 13) {
            my $isbn = Business::ISBN->new($code);
            if ($isbn && $isbn->is_valid) {
                $symbology = 'EAN13'; # ISBN-13 is a type of EAN-13
            }
            elsif (valid_barcode($code)) {
                $symbology = 'EAN13';
            }
        }
        elsif (length($code) == 12) {
            my $upc = Business::UPC->new($code);
            $symbology = 'UPCA' if ($upc && $upc->is_valid);
        }
        elsif (length($code) == 8) {
            my $upc = Business::UPC->type_e($code);
            if ($upc && $upc->is_valid) {
                $symbology = 'UPCE';
            } else {
                # If not a valid UPC-E, assume it's EAN-8.
                # SVG::Barcode::EAN8 will handle checksum validation.
                $symbology = 'EAN8';
            }
        }
        # Fallback for other numeric codes
        $symbology ||= 'Code128';
    } else {
        # Non-numeric codes become QR codes
        $symbology = 'QR';
    }
    return $c->reply->not_found unless ($symbology && $code);

    $c->app->log->debug("Generating barcode of type '$symbology' for code '$code'");

    my $svg_data = eval {
        my $generator;
        if ($symbology eq 'EAN13') {
            $generator = SVG::Barcode::EAN13->new();
        }
        elsif ($symbology eq 'UPCA') {
            $generator = SVG::Barcode::UPCA->new();
        }
        elsif ($symbology eq 'UPCE') {
            $generator = SVG::Barcode::UPCE->new();
        }
        elsif ($symbology eq 'EAN8') {
            $generator = SVG::Barcode::EAN8->new();
        }
        elsif ($symbology eq 'Code128') {
            $generator = SVG::Barcode::Code128->new();
        }
        elsif ($symbology eq 'QR') {
            $generator = SVG::Barcode::QRCode->new(); # QR code size is better controlled by height/width attributes on the <img>
        }
        return unless $generator;
        return $generator->plot($code);
    };
    if ($@ || !$svg_data) {
        $c->app->log->error("Barcode generation failed for code '$code': $@");
        return $c->reply->not_found;
    }

    # Set caching headers for one year
    $c->res->headers->header('Expires' => time2str(time + 365 * 24 * 60 * 60));

    $c->render(data => $svg_data, format => 'svg');
})->name('barcode_image');

# --- Tag Management ---

# GET /tags
get('/tags' => sub ($c) {
    my $tags_rs = $c->app->schema->resultset('Tag')->search({}, { order_by => 'tag' });
    $c->render(template => 'tags', tags => [ $tags_rs->all ]);
})->name('tags');

# POST /tag/create
post('/tag/create' => sub ($c) {
    my $tag_name = $c->param('tag');
    return $c->redirect_to('tags') unless $tag_name;

    eval {
        $c->app->schema->resultset('Tag')->create({ tag => $tag_name });
        $c->flash(message => "Tag '$tag_name' created.");
    };
    if ($@) {
        $c->flash(error => "Could not create tag. It may already exist. ($@)");
    }
    $c->redirect_to('tags');
})->name('tag_create');

# POST /tag/:id/delete
post('/tag/:id/delete' => sub ($c) {
    my $id = $c->param('id');
    my $tag = $c->app->schema->resultset('Tag')->find($id);
    return $c->reply->not_found unless $tag;

    my $tag_name = $tag->tag;
    $tag->delete; # Cascades to item_tags

    $c->flash(message => "Tag '$tag_name' and all its associations have been deleted.");
    $c->redirect_to('tags');
})->name('tag_delete');

# GET /tag/:id/edit
get('/tag/:id/edit' => sub ($c) {
    my $id = $c->param('id');
    my $tag = $c->app->schema->resultset('Tag')->find($id);
    return $c->reply->not_found unless $tag;
    $c->render(template => 'tag_edit', tag => $tag);
})->name('tag_edit');

# POST /tag/:id/update
post('/tag/:id/update' => sub ($c) {
    my $id = $c->param('id');
    my $tag = $c->app->schema->resultset('Tag')->find($id);
    return $c->reply->not_found unless $tag;

    my $new_name = $c->param('tag');
    $tag->update({ tag => $new_name });

    $c->flash(message => "Tag updated to '$new_name'.");
    $c->redirect_to('tags');
})->name('tag_update');

# --- Pattern Management ---

# GET /patterns
get('/patterns' => sub ($c) {
    my $patterns_rs = $c->app->schema->resultset('Pattern')->search(
        {},
        {
            order_by => { -asc => ['lower', 'upper'] },
            prefetch => 'item'
        }
    );

    # Build a hierarchical list of all items for the dropdown
    my %items_for_dropdown;
    my %children_of_for_dropdown;
    my $all_items_list = [ $c->app->schema->resultset('Item')->search({}, { prefetch => ['items', 'gtins'] })->all ];
    for my $i (@$all_items_list) {
        $items_for_dropdown{$i->id} = $i;
        push @{ $children_of_for_dropdown{$i->parent_id || 0} }, $i->id;
    }
    my $build_item_tree;
    $build_item_tree = sub {
        my ($parent_id, $level) = @_;
        my @nodes;
        return unless exists $children_of_for_dropdown{$parent_id};
        for my $item_id (sort { lc($items_for_dropdown{$a}->short_description) cmp lc($items_for_dropdown{$b}->short_description) } @{$children_of_for_dropdown{$parent_id}}) {
            my $item_node = $items_for_dropdown{$item_id};
            my $is_parent = $item_node->items->count > 0 || $item_node->gtins->count == 0;
            push @nodes, { item => $item_node, level => $level, is_parent => $is_parent };
            push @nodes, $build_item_tree->($item_id, $level + 1);
        }
        return @nodes;
    };
    my @all_items_tree = $build_item_tree->(0, 0);

    $c->render(
        template => 'patterns',
        patterns => [ $patterns_rs->all ],
        all_items_tree => \@all_items_tree
    );
})->name('patterns');

# POST /pattern/create
post('/pattern/create' => sub ($c) {
    eval {
        # Ensure item_id is undef if an empty string is passed
        my $item_id = $c->param('item_id');
        $item_id = undef if defined $item_id && $item_id eq '';

        $c->app->schema->resultset('Pattern')->create({
            lower   => $c->param('lower'),
            upper   => $c->param('upper'),
            comment => $c->param('comment'),
            item_id => $c->param('item_id') || undef,
        });
        $c->flash(message => "Pattern created.");
    };
    if ($@) {
        $c->flash(error => "Failed to create pattern: $@");
    }
    $c->redirect_to('patterns');
})->name('pattern_create');

# GET /pattern/:id/edit
get('/pattern/:id/edit' => sub ($c) {
    my $id = $c->param('id');
    my $pattern = $c->app->schema->resultset('Pattern')->find($id);
    return $c->reply->not_found unless $pattern;

    # Build a hierarchical list of all items for the dropdown
    my %items_for_dropdown;
    my %children_of_for_dropdown;
    my $all_items_list = [ $c->app->schema->resultset('Item')->search({}, { prefetch => ['items', 'gtins'] })->all ];
    for my $i (@$all_items_list) {
        $items_for_dropdown{$i->id} = $i;
        push @{ $children_of_for_dropdown{$i->parent_id || 0} }, $i->id;
    }
    my $build_item_tree;
    $build_item_tree = sub {
        my ($parent_id, $level) = @_;
        my @nodes;
        return unless exists $children_of_for_dropdown{$parent_id};
        for my $item_id (sort { lc($items_for_dropdown{$a}->short_description) cmp lc($items_for_dropdown{$b}->short_description) } @{$children_of_for_dropdown{$parent_id}}) {
            my $item_node = $items_for_dropdown{$item_id};
            my $is_parent = $item_node->items->count > 0 || $item_node->gtins->count == 0;
            push @nodes, { item => $item_node, level => $level, is_parent => $is_parent };
            push @nodes, $build_item_tree->($item_id, $level + 1);
        }
        return @nodes;
    };
    my @all_items_tree = $build_item_tree->(0, 0);

    $c->render(
        template => 'pattern_edit',
        pattern => $pattern,
        all_items_tree => \@all_items_tree
    );
})->name('pattern_edit');


# POST /pattern/:id/update
post('/pattern/:id/update' => sub ($c) {
    my $id = $c->param('id');
    my $pattern = $c->app->schema->resultset('Pattern')->find($id);
    return $c->reply->not_found unless $pattern;

    eval {
        $pattern->update({
            lower   => $c->param('lower'),
            upper   => $c->param('upper'),
            comment => $c->param('comment'),
            item_id => $c->param('item_id') || undef,
        });
        $c->flash(message => "Pattern updated.");
    };
    if ($@) {
        $c->flash(error => "Failed to update pattern: $@");
    }
    $c->redirect_to('patterns');
})->name('pattern_update');

# POST /pattern/:id/delete
post('/pattern/:id/delete' => sub ($c) {
    my $id = $c->param('id');
    my $pattern = $c->app->schema->resultset('Pattern')->find($id);
    return $c->reply->not_found unless $pattern;
    $pattern->delete;
    $c->flash(message => "Pattern deleted.");
    $c->redirect_to($c->param('redirect_to') || $c->url_for('patterns'));
})->name('pattern_delete');

# --- Location & Inventory Management ---

# GET /locations
get('/locations' => sub ($c) {
    my $locations_rs = $c->app->schema->resultset('Location')->search({}, { order_by => 'full_name' });
    # Pass an array to the template
    $c->render(template => 'locations', locations => [ $locations_rs->all ]);
})->name('locations');

# POST /location/create
post('/location/create' => sub ($c) {
    $c->app->schema->resultset('Location')->create({
        short_name => $c->param('short_name'),
        full_name  => $c->param('full_name'),
    });
    $c->flash(message => "Location created.");
    $c->redirect_to('locations');
})->name('location_create');

# POST /inventory/adjust
post('/inventory/adjust' => sub ($c) {
    my $item_id     = $c->param('item_id');
    my $location_id = $c->param('location_id');
    my $action      = $c->param('action'); # 'add' or 'remove'

    my $item = $c->app->schema->resultset('Item')->find($item_id);
    my $loc  = $c->app->schema->resultset('Location')->find($location_id);
    return $c->reply->not_found unless $item && $loc;

    if ($action eq 'add') {
        $c->app->schema->resultset('Inventory')->create({
            item_id     => $item_id,
            location_id => $location_id,
        });
        $c->flash(message => "Added one '".$item->short_description."' to '".$loc->short_name."'.");
    }
    elsif ($action eq 'remove') {
        my $inventory_item = $c->app->schema->resultset('Inventory')->search(
            { item_id => $item_id, location_id => $location_id },
            { order_by => { -asc => 'added_at' }, rows => 1 }
        )->first;

        if ($inventory_item) {
            $inventory_item->delete;
            $c->flash(message => "Removed one '".$item->short_description."' from '".$loc->short_name."'.");
        } else {
            $c->flash(error => "No '".$item->short_description."' found in '".$loc->short_name."' to remove.");
        }
    }

    # Redirect back to the page the user was on
    my $redirect_to = $c->param('redirect_to') || '/item/' . $item_id;
    $c->redirect_to($redirect_to);
})->name('inventory_adjust');

# POST /inventory/set_quantity
post('/inventory/set_quantity' => sub ($c) {
    my $item_id     = $c->param('item_id');
    my $location_id = $c->param('location_id');
    my $quantity    = $c->param('quantity');

    return $c->reply->bad_request('Invalid quantity') unless defined $quantity && $quantity =~ /^\d+$/;

    my $item = $c->app->schema->resultset('Item')->find($item_id);
    my $loc  = $c->app->schema->resultset('Location')->find($location_id);
    return $c->reply->not_found unless $item && $loc;

    $c->app->schema->txn_do(sub {
        # Remove all existing inventory for this item/location
        $c->app->schema->resultset('Inventory')->search({
            item_id     => $item_id,
            location_id => $location_id,
        })->delete_all;

        # Add the new quantity
        $c->app->schema->resultset('Inventory')->populate([
            ({ item_id => $item_id, location_id => $location_id })
        x $quantity]) if $quantity > 0;
    });

    $c->flash(message => "Quantity for '".$item->short_description."' in '".$loc->short_name."' set to $quantity.");
    if ($c->req->is_xhr) {
        return $c->render(json => { success => 1, message => "Quantity set to $quantity." });
    } else {
        $c->redirect_to($c->url_for('location_show', {id => $location_id}));
    }
})->name('inventory_set_quantity');

# GET /location/:id
get('/location/:id' => sub ($c) {
    my $id = $c->param('id');
    my $location = $c->app->schema->resultset('Location')->find($id);
    return $c->reply->not_found unless $location;

    # 1. Get direct counts for all items in THIS location
    my %item_counts;
    my $counts_rs = $c->app->schema->resultset('Inventory')->search(
        { location_id => $id },
        {
            select   => [ 'item_id', { count => 'item_id' } ],
            as       => [qw/item_id count/],
            group_by => 'item_id'
        }
    );
    while (my $row = $counts_rs->next) {
        $item_counts{$row->get_column('item_id')} = $row->get_column('count');
    }

    # 2. Build a tree of ALL items in the database, just like the dashboard
    my %items;
    my %children_of;
    my $all_items = [ $c->app->schema->resultset('Item')->search({}, { prefetch => ['items', 'gtins'] })->all ];
    for my $item (@$all_items) {
        $items{$item->id} = $item;
        push @{ $children_of{$item->parent_id || 0} }, $item->id;
    }

    # 3. Recursively build the display tree, pruning branches with no inventory in this location
    my $build_items_in_loc_tree;
    $build_items_in_loc_tree = sub {
        my ($parent_id, $level) = @_;
        my @nodes;
        return unless exists $children_of{$parent_id};
        for my $item_id (sort { lc($items{$a}->short_description) cmp lc($items{$b}->short_description) } @{$children_of{$parent_id}}) {
            my $item_node = $items{$item_id};
            my $direct_count = $item_counts{$item_id} || 0;
            my @child_nodes = $build_items_in_loc_tree->($item_id, $level + 1);

            my $total_count_in_loc = $direct_count;
            $total_count_in_loc += $_->{total_count} for @child_nodes;

            next if $total_count_in_loc == 0;

            my $is_parent = $item_node->items->count > 0 || $item_node->gtins->count == 0;
            push @nodes, { item => $item_node, level => $level, is_parent => $is_parent, count => $direct_count, total_count => $total_count_in_loc, children => \@child_nodes };
        }
        return @nodes;
    };
    my @items_in_location_tree = $build_items_in_loc_tree->(0, 0);

    # Build a hierarchical list of all items for the dropdown
    my %items_for_dropdown;
    my %children_of_for_dropdown;
    my $all_items_list = [ $c->app->schema->resultset('Item')->search({}, { prefetch => ['items', 'gtins'] })->all ];
    for my $i (@$all_items_list) {
        $items_for_dropdown{$i->id} = $i;
        push @{ $children_of_for_dropdown{$i->parent_id || 0} }, $i->id;
    }
    my $build_item_tree;
    $build_item_tree = sub {
        my ($parent_id, $level) = @_;
        my @nodes;
        return unless exists $children_of_for_dropdown{$parent_id};
        for my $item_id (sort { lc($items_for_dropdown{$a}->short_description) cmp lc($items_for_dropdown{$b}->short_description) } @{$children_of_for_dropdown{$parent_id}}) {
            my $item_node = $items_for_dropdown{$item_id};
            my $is_parent = $item_node->items->count > 0 || $item_node->gtins->count == 0;
            push @nodes, { item => $item_node, level => $level, is_parent => $is_parent };
            push @nodes, $build_item_tree->($item_id, $level + 1);
        }
        return @nodes;
    };
    my @all_items_tree = $build_item_tree->(0, 0);

    $c->render(
        template => 'location',
        location => $location,
        items_in_location_tree => \@items_in_location_tree,
        all_items_tree         => \@all_items_tree
    );
})->name('location_show');


app->start;
__DATA__

@@ layouts/layout.html.ep
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Inventory</title>
    <style>
        body { font-family: sans-serif; margin: 0; background-color: #f4f4f9; }
        nav { background: #333; color: white; padding: 1rem; }
        nav a { color: white; text-decoration: none; margin-right: 15px; }
        nav a:hover { text-decoration: underline; }
        .container { padding: 2rem; }
        h1, h2, h3 { border-bottom: 2px solid #ddd; padding-bottom: 10px; color: #333; }
        table { border-collapse: collapse; width: 100%; margin-top: 1rem; background: white; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        form { display: grid; gap: 1rem; background: white; padding: 1.5rem; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-top: 1rem; max-width: 100%; }
        form input, form select, form textarea { width: 100%; box-sizing: border-box; }
        input, select, button { padding: 0.8rem; border: 1px solid #ccc; border-radius: 4px; font-size: 1rem; }
        button { background-color: #5cb85c; color: white; border: none; cursor: pointer; }
        button:hover { background-color: #4cae4c; }
        button.delete { background-color: #d9534f; }
        button.delete:hover { background-color: #c9302c; }
        .flash { padding: 1rem; margin: 1rem 0; border-radius: 5px; }
        .flash.message { background-color: #dff0d8; color: #3c763d; border: 1px solid #d6e9c6; }
        .flash.error { background-color: #f2dede; color: #a94442; border: 1px solid #ebccd1; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1.5rem; }
        .panel { background: white; padding: 1.5rem; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }

        @media (max-width: 768px) {
            .grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
<body>
    <nav>
        <a href="<%= url_for('/') %>">Dashboard</a>
        <a href="<%= url_for('items') %>">Items</a>
        <a href="<%= url_for('gtins') %>">Barcodes</a>
        <a href="<%= url_for('locations') %>">Locations</a>
        <a href="<%= url_for('tags') %>">Tags</a>
        <a href="<%= url_for('patterns') %>">Patterns</a>
    </nav>
    <div class="container">
        % if (my $msg = flash('message')) {
            <div class="flash message"><%= $msg %></div>
        % }
        % if (my $err = flash('error')) {
            <div class="flash error"><%= $err %></div>
        % }
        <%= content %>
    </div>
    <div id="toast-container" style="position: fixed; top: 20px; right: 20px; z-index: 1050;"></div>

    <script>
        function showToast(message, isError = false) {
            const toastId = 'toast-' + Date.now();
            const toastClass = isError ? 'flash error' : 'flash message';
            const toast = $(`<div id="${toastId}" class="${toastClass}" style="display: none;">${message}</div>`);
            $('#toast-container').append(toast);
            toast.fadeIn(300);
            setTimeout(() => {
                toast.fadeOut(400, () => toast.remove());
            }, 3000);
        }

        $(document).ready(function() {
            // Handle dynamic forms
            $('body').on('submit', 'form.dynamic-form', function(e) {
                e.preventDefault();
                const $form = $(this);
                const url = $form.attr('action');
                const method = $form.attr('method');

                $.ajax({
                    url: url,
                    type: method,
                    data: $form.serialize(),
                    dataType: 'json',
                    success: function(data) {
                        showToast(data.message || 'Success!');
                    },
                    error: function(xhr) {
                        const errorMsg = xhr.responseJSON ? xhr.responseJSON.error : 'An unknown error occurred.';
                        showToast(errorMsg, true);
                    }
                });
            });
        });
    </script>
    <script>
        document.querySelectorAll('button.delete').forEach(button => {
            button.addEventListener('click', e => {
                if (!confirm('Are you sure you want to delete this? This action cannot be undone.')) {
                    e.preventDefault();
                }
            });
        });
    </script>
</body>
</html>

@@ index.html.ep
% layout 'layout';
<h1>Dashboard</h1>
<div class="grid">
    <div class="panel">
        <h2>Inventory Summary</h2>
        % if (@$inventory_summary) {
            <ul style="list-style-type: none; padding-left: 0;">
            % # Create a recursive template partial
            % my $render_node;
            % $render_node = begin
                % my ($node, $level) = @_;
                % my $style = $node->{is_parent} ? 'font-weight: bold;' : '';
                <li style="padding-left: <%= $level * 20 %>px;">
                    <a href="<%= url_for('item_show', {id => $node->{item}->id}) %>" style="<%= $style %>">
                        <%= $node->{item}->short_description %></a>
                    <strong>(Total: <%= $node->{total_count} %>)</strong>
                    % if ($node->{direct_count} > 0) {
                        <span style="color: #555;">
                            (<%= $node->{direct_count} %>
                            % if ($node->{locations}) {
                                in <%= $node->{locations} %>)
                            % } else {
                                )
                            % }
                        </span>
                    % }

                    % if (@{$node->{children}}) {
                        <ul style="list-style-type: none; padding-left: 0;">
                        % for my $child_node (@{$node->{children}}) {
                            <%= $render_node->($child_node, $level + 1) %>
                        % }
                        </ul>
                    % }
                </li>
            % end
            % for my $node (@$inventory_summary) {
                <%= $render_node->($node, 0) %>
            % }
            </ul>
        % } else {
            <p>No items in inventory.</p>
        % }
    </div>
    <div class="panel">
        <h2>Recent Scans</h2>
        % if ($recent_scans->count) {
            <table>
                <thead><tr><th>Code</th><th>Time</th><th>Claimed</th></tr></thead>
                <tbody>
                % for my $scan ($recent_scans->all) {
                    <tr>
                        <td><%= $scan->code %></td>
                        <td><%= $scan->date_added %></td>
                        <td><%= $scan->claimed ? 'Yes' : 'No' %></td>
                    </tr>
                % }
                </tbody>
            </table>
        % } else {
            <p>No recent scans found.</p>
        % }
    </div>
</div>

@@ items.html.ep
% layout 'layout';
<h1>Items</h1>
<div class="grid">
    <div class="panel">
        <h2>All Items</h2>
        % if (@$item_tree) {
            <ul style="list-style-type: none; padding-left: 0;">
                % for my $node (@$item_tree) {
                    % my $item = $node->{item};
                    % my $indent = $node->{level} * 20;
                    % my $style = $node->{is_parent} ? 'font-weight: bold;' : '';
                    <li style="padding-left: <%= $indent %>px; margin-bottom: 5px;">
                        <a href="<%= url_for('item_show', {id => $item->id}) %>" style="<%= $style %>">
                            <%= $item->short_description %></a>
                        % if ($item->description) {
                            <span style="color: #666; font-size: 0.9em;">- <%= $item->description %></span>
                        % }
                    </li>
                % }
            </ul>
        % } else {
            <p>No items found.</p>
        % }
    </div>
    <div class="panel">
        <h2>Add New Item</h2>
        <form action="<%= url_for('item_create') %>" method="POST">
            <label for="short_description">Short Description:</label>
            <input type="text" name="short_description" required>
            <label for="parent_id">Parent Item (Optional):</label>
            <select name="parent_id">
                <option value="">-- None --</option>
                % for my $node (@$parent_item_list) {
                    % my $p_item = $node->{item};
                    % my $indent = '&nbsp;&nbsp;' x $node->{level};
                    % my $style = 'font-weight: bold;';
                    <option value="<%= $p_item->id %>" style="<%= $style %>"><%= Mojo::ByteStream->new($indent) %><%= $p_item->short_description %></option>
                % }
            </select>
            <button type="submit">Create Item</button>
        </form>
    </div>
</div>

@@ gtins.html.ep
% layout 'layout';

<h1>All Barcodes (GTINs)</h1>
<div class="panel">
    <table>
        <thead>
            <tr>
                <th>GTIN</th>
                <th>Barcode</th>
                <th>Linked Item</th>
                <th># per scan</th>
            </tr>
        </thead>
        <tbody>
        % for my $gtin (@$gtins) {
            <tr>
                <td><%= $gtin->gtin %></td>
                <td>
                    <img src="<%= url_for('barcode_image', {code => $gtin->gtin}) %>" alt="Barcode for <%= $gtin->gtin %>" height="100">
                </td>
                <td>
                    % if (my $item = $gtin->item) {
                        <a href="<%= url_for('item_show', {id => $item->id}) %>"><%= $item->short_description %></a>
                    % } else {
                        <span style="color: #999;">Not linked</span>
                    % }
                </td>
                <td>
                    <form class="dynamic-form" action="<%= url_for('gtin_update_quantity', {id => $gtin->id}) %>" method="POST" style="box-shadow:none; padding:0; display:flex; gap:5px;">
                        <input type="number" name="quantity" value="<%= $gtin->item_quantity %>" min="1" style="width: 60px;">
                        <input type="hidden" name="redirect_to" value="<%= url_for('gtins') %>">
                        <button type="submit" style="padding: 5px 10px;">Set</button>
                    </form>
                </td>
            </tr>
        % }
        </tbody>
    </table>
</div>

@@ item.html.ep
% layout 'layout';
<h1>Item: <%= $item->short_description %></h1>

<div class="grid">
    <div class="panel">
        <h2>Edit Item Details</h2>
        <form action="<%= url_for('/item/' . $item->id . '/update') %>" method="POST">
            <label for="short_description">Short Description:</label>
            <input type="text" name="short_description" value="<%= $item->short_description %>" required>
            <label for="description">Long Description (optional):</label>
            <input type="text" name="description" value="<%= $item->description %>">
            <label for="parent_id">Parent Item:</label>
            <select name="parent_id">
                <option value="">-- None --</option>
                % for my $node (@$parent_item_list) {
                    % next unless $node->{is_parent};
                    % my $p_item = $node->{item};
                    % my $indent = '&nbsp;&nbsp;' x $node->{level};
                    % my $style = $node->{is_parent} ? 'font-weight: bold;' : '';
                    <option value="<%= $p_item->id %>" <%= ($item->parent_id && $item->parent_id == $p_item->id) ? 'selected' : '' %> style="<%= $style %>"><%= Mojo::ByteStream->new($indent) %><%= $p_item->short_description %></option>
                % }
            </select>
            <button type="submit">Update Item</button>
        </form>
        <form action="<%= url_for('/item/' . $item->id . '/delete') %>" method="POST" style="margin-top: 1rem;">
            <button type="submit" class="delete">Delete This Item</button>
        </form>
    </div>
    <div class="panel">
        <h2>Barcodes (GTINs)</h2>
        <table style="width: 100%; table-layout: fixed;">
            <colgroup>
                <col style="width: 30%;">
                <col style="width: 40%;">
                <col style="width: 15%;">
                <col style="width: 15%;">
            </colgroup>
            <thead><tr><th>GTIN</th><th>Barcode</th><th># per scan</th><th>Action</th></tr></thead>
            % for my $gtin ($item->gtins) {
            <tr>
                <td><%= $gtin->gtin %></td>
                <td><img src="<%= url_for('barcode_image', {code => $gtin->gtin}) %>" alt="Barcode for <%= $gtin->gtin %>" height="100"></td>
                <td>
                    <form class="dynamic-form" action="<%= url_for('gtin_update_quantity', {id => $gtin->id}) %>" method="POST" style="box-shadow:none; padding:0; display:flex; flex-direction: column; gap:5px;">
                        <input type="number" name="quantity" value="<%= $gtin->item_quantity %>" min="1" style="width: 100%; box-sizing: border-box;">
                        <input type="hidden" name="redirect_to" value="<%= url_for('item_show', {id => $item->id}) %>">
                        <button type="submit" style="padding: 5px 10px;">Set</button>
                    </form>
                </td><td>
                    <form action="<%= url_for('/gtin/' . $gtin->id . '/delete') %>" method="POST" style="padding:0; box-shadow:none;">
                        <button type="submit" class="delete" style="padding: 5px 10px;">Remove</button>
                    </form>
                </td>
            </tr>
            % }
        </table>
        <h3>Add GTIN</h3>
        <form action="<%= url_for('/item/' . $item->id . '/add_gtin') %>" method="POST">
            <input type="text" name="gtin" placeholder="Scan or type barcode" required>
            <button type="submit">Add GTIN</button>
        </form>
    </div>

    <div class="panel">
        <h2>Inventory Locations</h2>
        <table>
            <thead>
                <tr>
                    <th>Location</th>
                    <th>Count</th>
                </tr>
            </thead>
            % for my $loc (@$locations) {
            <tr>
                <td><%= $loc->get_column('location_name') || 'Unknown' %></td>
                <td>
                    <form class="dynamic-form" action="<%= url_for('inventory_set_quantity') %>" method="POST" style="box-shadow:none; padding:0; display:flex; gap:5px;">
                        <input type="hidden" name="item_id" value="<%= $item->id %>">
                        <input type="hidden" name="location_id" value="<%= $loc->get_column('location_id') %>">
                        <input type="number" name="quantity" value="<%= $loc->get_column('count') %>" min="0" style="width: 100%; box-sizing: border-box;">
                        <button type="submit" style="padding: 5px 10px;">Set</button>
                    </form>
                </td>
            </tr>
            % }
        </table>
        <h3>Adjust Inventory</h3>
        <form action="<%= url_for('inventory_adjust') %>" method="POST">
            <input type="hidden" name="item_id" value="<%= $item->id %>">
            <label for="location_id">Location:</label>
            <select name="location_id">
                % for my $node (@$all_locations_list) {
                    % my $loc = $node->{location};
                    % my $indent = '&nbsp;&nbsp;' x $node->{level};
                    <option value="<%= $loc->id %>"><%= Mojo::ByteStream->new($indent) %><%= $loc->full_name %></option>
                % }
            </select>
            <div style="display: flex; gap: 1rem;">
                <button type="submit" name="action" value="add">Add One</button>
                <button type="submit" name="action" value="remove" class="delete">Remove One</button>
            </div>
        </form>
    </div>

    <div class="panel">
        <h2>Item Tags</h2>
        % if ($item->item_tags->count) {
            <ul style="list-style-type: none; padding: 0; display: flex; flex-wrap: wrap; gap: 10px;">
            % for my $item_tag ($item->item_tags) {
                <li style="background: #eee; padding: 5px 10px; border-radius: 15px; display: flex; align-items: center; gap: 5px;">
                    <span><%= $item_tag->tag->tag %></span>
                    <form action="<%= url_for('/item_tag/' . $item_tag->id . '/delete') %>" method="POST" style="padding:0; box-shadow:none; margin:0;">
                        <button type="submit" class="delete" style="padding: 0; width: 20px; height: 20px; line-height: 20px; border-radius: 50%; font-size: 12px;">X</button>
                    </form>
                </li>
            % }
            </ul>
        % } else {
            <p>No tags associated with this item.</p>
        % }
        <h3>Add Tag</h3>
        <form action="<%= url_for('/item/' . $item->id . '/add_tag') %>" method="POST">
            <select name="tag_id" required>
                <option value="">-- Select a Tag --</option>
                % for my $tag (@$all_tags) {
                    <option value="<%= $tag->id %>"><%= $tag->tag %></option>
                % }
            </select>
            <button type="submit">Add Tag</button>
        </form>
    </div>

</div>
@@ locations.html.ep
% layout 'layout';
<h1>Locations</h1>
<div class="grid">
    <div class="panel">
        <h2>All Locations</h2>
        <table style="width: 100%;">
            <thead><tr><th style="width: 5%;">ID</th><th style="width: 40%;">Full Name</th><th style="width: 20%;">Short Name</th><th style="width: 15%;">Actions</th><th style="width: 20%;">Codes</th></tr></thead>
            <tbody>
            % for my $loc (@$locations) {
                <tr>
                    <td><%= $loc->id %></td>
                    <td><%= $loc->full_name %></td>
                    <td><%= $loc->short_name %></td>
                    <td>
                        <a href="<%= url_for('location_show', {id => $loc->id}) %>">View/Manage</a>
                    </td>
                    <td>
                        <div style="display: flex; gap: 1em; margin-top: 0.5em;">
                            <div style="text-align: center;">
                                <img src="<%= url_for('barcode_image', {code => 'inventory://' . $loc->short_name . '/add'}) %>" alt="QR Code for adding to <%= $loc->short_name %>" width="100" height="100">
                                <div>Add</div>
                            </div>
                            <div style="text-align: center;">
                                <img src="<%= url_for('barcode_image', {code => 'inventory://' . $loc->short_name . '/remove'}) %>" alt="QR Code for removing from <%= $loc->short_name %>" width="100" height="100">
                                <div>Remove</div>
                            </div>
                        </div>
                    </td>
                </tr>
            % }
            </tbody>
        </table>
    </div>
    <div class="panel">
        <h2>Add New Location</h2>
        <form action="<%= url_for('location_create') %>" method="POST">
            <label for="short_name">Short Name:</label>
            <input type="text" name="short_name" required>
            <label for="full_name">Full Name:</label>
            <input type="text" name="full_name" required>
            <button type="submit">Create Location</button>
        </form>
    </div>
</div>

@@ tags.html.ep
% layout 'layout';
<h1>Tags</h1>

<div class="grid">
    <div class="panel">
        <h2>All Tags</h2>
        % if (@$tags) {
            <table>
                <thead><tr><th>Tag</th><th>Action</th></tr></thead>
                <tbody>
                % for my $tag (@$tags) {
                    <tr>
                        <td><%= $tag->tag %></td>
                        <td>
                            <div style="display: flex; gap: 5px;">
                                <a href="<%= url_for('tag_edit', {id => $tag->id}) %>" style="text-decoration: none;"><button style="padding: 5px 10px;">Edit</button></a>
                                <form action="<%= url_for('tag_delete', {id => $tag->id}) %>" method="POST" style="padding:0; box-shadow:none; margin:0;"><button type="submit" class="delete" style="padding: 5px 10px;">Delete</button></form>
                            </div>
                        </td>
                    </tr>
                % }
                </tbody>
            </table>
        % } else {
            <p>No tags found. Create one!</p>
        % }
    </div>
    <div class="panel">
        <h2>Add New Tag</h2>
        <form action="<%= url_for('tag_create') %>" method="POST">
            <label for="tag">Tag Name:</label>
            <input type="text" name="tag" required>
            <button type="submit">Create Tag</button>
        </form>
    </div>
</div>

@@ tag_edit.html.ep
% layout 'layout';
<h1>Edit Tag</h1>

<div class="panel">
    <form action="<%= url_for('tag_update', {id => $tag->id}) %>" method="POST">
        <label for="tag">Tag Name:</label>
        <input type="text" name="tag" value="<%= $tag->tag %>" required>
        <button type="submit">Update Tag</button>
    </form>
</div>


@@ patterns.html.ep
% layout 'layout';
<h1>Barcode Patterns</h1>

<div class="grid">
    <div class="panel">
        <h2>All Patterns</h2>
        % if (@$patterns) {
            <table>
                <thead>
                    <tr>
                        <th>Lower Bound</th>
                        <th>Upper Bound</th>
                        <th>Linked Item</th>
                        <th>Comment</th>
                        <th>Action</th>
                    </tr>
                </thead>
                <tbody>
                % for my $p (@$patterns) {
                    <tr>
                        <td><%= $p->lower %></td>
                        <td><%= $p->upper %></td>
                        <td>
                            % if (my $item = $p->item) {
                                <a href="<%= url_for('item_show', {id => $item->id}) %>"><%= $item->short_description %></a>
                            % } else {
                                <span style="color: #999;">(None)</span>
                            % }
                        </td>
                        <td><%= $p->comment %></td>
                        <td style="display: flex; gap: 5px;">
                            <a href="<%= url_for('pattern_edit', {id => $p->id}) %>" style="text-decoration: none;"><button style="padding: 5px 10px;">Edit</button></a>
                            <form action="<%= url_for('pattern_delete', {id => $p->id}) %>" method="POST" style="padding:0; box-shadow:none; margin:0;">
                                <button type="submit" class="delete" style="padding: 5px 10px;">Delete</button>
                            </form>
                        </td>
                    </tr>
                % }
                </tbody>
            </table>
        % } else {
            <p>No patterns defined.</p>
        % }
    </div>
    <div class="panel">
        <h2>Add New Pattern</h2>
        <form action="<%= url_for('pattern_create') %>" method="POST">
            <label for="lower">Lower Bound:</label>
            <input type="number" name="lower" required>

            <label for="upper">Upper Bound:</label>
            <input type="number" name="upper" required>

            <label for="comment">Comment (optional):</label>
            <input type="text" name="comment">

            <label for="item_id">Linked Item (optional):</label>
            <select name="item_id">
                <option value="">-- None (Discard Barcode) --</option>
                % for my $node (@$all_items_tree) {
                    % my $item = $node->{item};
                    % my $indent = '&nbsp;&nbsp;' x $node->{level};
                    % my $style = $node->{is_parent} ? 'font-weight: bold;' : '';
                    <option value="<%= $item->id %>" style="<%= $style %>"><%= Mojo::ByteStream->new($indent) %><%= $item->short_description %></option>
                % }
            </select>

            <button type="submit">Create Pattern</button>
        </form>
    </div>
</div>

@@ pattern_edit.html.ep
% layout 'layout';
<h1>Edit Pattern</h1>

<div class="panel">
    <form action="<%= url_for('pattern_update', {id => $pattern->id}) %>" method="POST">
        <label for="lower">Lower Bound:</label>
        <input type="number" name="lower" value="<%= $pattern->lower %>" required>

        <label for="upper">Upper Bound:</label>
        <input type="number" name="upper" value="<%= $pattern->upper %>" required>

        <label for="comment">Comment (optional):</label>
        <input type="text" name="comment" value="<%= $pattern->comment %>">

        <label for="item_id">Linked Item (optional):</label>
        <select name="item_id">
            <option value="">-- None (Discard Barcode) --</option>
            % for my $node (@$all_items_tree) {
                % my $item = $node->{item};
                % my $indent = '&nbsp;&nbsp;' x $node->{level};
                % my $style = $node->{is_parent} ? 'font-weight: bold;' : '';
                <option value="<%= $item->id %>" <%= ($pattern->item_id && $pattern->item_id == $item->id) ? 'selected' : '' %> style="<%= $style %>"><%= Mojo::ByteStream->new($indent) %><%= $item->short_description %></option>
            % }
        </select>

        <button type="submit">Update Pattern</button>
    </form>
</div>

@@ location.html.ep
% layout 'layout';
<h1>Location: <%= $location->full_name %></h1>

<div class="grid">
    <div class="panel">
        <h2>Items in this Location</h2>
        % if (@$items_in_location_tree) {
            <table>
                <thead><tr><th>Item</th><th style="width: 150px;">Count</th></tr></thead>
                <tbody>
                % my $render_node;
                % $render_node = begin
                    % my ($node) = @_;
                    % my $item = $node->{item};
                    % my $indent = $node->{level} * 20;
                    % my $style = $node->{is_parent} ? 'font-weight: bold;' : '';
                    <tr style="background-color: <%= $node->{level} % 2 ? '#f9f9f9' : 'white' %>;">
                        <td style="padding-left: <%= $indent + 12 %>px;">
                            <a href="<%= url_for('item_show', {id => $item->id}) %>" style="<%= $style %>"><%= $item->short_description %></a>
                            % if ($node->{is_parent}) {
                                <strong>(Total: <%= $node->{total_count} %>)</strong>
                            % }
                        </td>
                        <td>
                            % unless ($node->{is_parent}) {
                                <form class="dynamic-form" action="<%= url_for('inventory_set_quantity') %>" method="POST" style="box-shadow:none; padding:0; display:flex; gap:5px;">
                                    <input type="hidden" name="item_id" value="<%= $item->id %>">
                                    <input type="hidden" name="location_id" value="<%= $location->id %>">
                                    <input type="number" name="quantity" value="<%= $node->{count} %>" min="0" style="width: 100%; box-sizing: border-box;">
                                    <button type="submit" style="padding: 5px 10px;">Set</button>
                                </form>
                            % } else {
                                &nbsp;
                            % }
                        </td>
                    </tr>
                    % for my $child_node (@{$node->{children}}) {
                        <%= $render_node->($child_node) %>
                    % }
                % end
                % for my $node (@$items_in_location_tree) {
                    <%= $render_node->($node) %>
                % }
                </tbody>
            </table>
        % } else {
            <p>This location is empty.</p>
        % }
    </div>
    <div class="panel">
        <h2>Add Item to Location</h2>
        <form action="<%= url_for('inventory_adjust') %>" method="POST">
            <input type="hidden" name="location_id" value="<%= $location->id %>">
            <input type="hidden" name="redirect_to" value="<%= url_for('location_show', {id => $location->id}) %>">
            <label for="item_id">Item:</label>
            <select name="item_id">
                % for my $node (@$all_items_tree) {
                    % my $item = $node->{item};
                    % my $indent = '&nbsp;&nbsp;' x $node->{level};
                    % my $style = $node->{is_parent} ? 'font-weight: bold;' : '';
                    <option value="<%= $item->id %>" style="<%= $style %>"><%= Mojo::ByteStream->new($indent) %><%= $item->short_description %></option>
                % }
            </select>
            <div style="display: flex; gap: 1rem;">
                <button type="submit" name="action" value="add">Add One</button>
                <button type="submit" name="action" value="remove" class="delete">Remove One</button>
            </div>
        </form>
    </div>
</div>
