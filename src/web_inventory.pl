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
    my $all_items = [ $c->app->schema->resultset('Item')->all ];
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

        for my $id (sort { $items{$a}->short_description cmp $items{$b}->short_description } @{$children_of{$parent_id}}) {
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

            push @nodes, { item => $item, direct_count => $direct_count, total_count => $total_count, children => \@child_nodes, locations => $locations_str };
        }
        return @nodes;
    };

    my @inventory_summary = $build_tree->(0);

    my $recent_scans = $c->app->scans_schema->resultset('Scan')->search(
        {},
        {
            order_by => { -desc => 'date_added' },
            rows => 10
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
    my $items_rs = $c->app->schema->resultset('Item')->search(
        {},
        {
            order_by => { -asc => 'me.short_description' },
            prefetch => 'parent'
        }
    );
    # Pass an array to the template to avoid iterator exhaustion
    $c->render(template => 'items', items => [ $items_rs->all ]);
})->name('items');

# GET /item/:id
get('/item/:id' => sub ($c) {
    my $id = $c->param('id');
    my $item = $c->app->schema->resultset('Item')->find($id, {
        prefetch => ['gtins', 'parent', 'category']
    });
    unless ($item) {
        $c->flash(error => "Item with ID '$id' was not found.");
        return $c->redirect_to('items');
    }

    my $locations_rs = $c->app->schema->resultset('Inventory')->search(
        { item_id => $id },
        {
            select   => [ 'location.short_name', { count => 'location_id' } ],
            as       => [qw/location_name count/],
            join     => 'location',
            group_by => 'location.short_name'
        }
    );

    # Build a hierarchical list of possible parent items for the dropdown
    my %items_for_dropdown;
    my %children_of_for_dropdown;
    my $possible_parents = [ $c->app->schema->resultset('Item')->search({ id => { '!=' => $id } })->all ];
    for my $i (@$possible_parents) {
        $items_for_dropdown{$i->id} = $i;
        push @{ $children_of_for_dropdown{$i->parent_id || 0} }, $i->id;
    }

    my $build_parent_tree;
    $build_parent_tree = sub {
        my ($parent_id, $level) = @_;
        my @nodes;
        return unless exists $children_of_for_dropdown{$parent_id};

        for my $item_id (sort { $items_for_dropdown{$a}->short_description cmp $items_for_dropdown{$b}->short_description } @{$children_of_for_dropdown{$parent_id}}) {
            my $item_node = $items_for_dropdown{$item_id};
            push @nodes, { item => $item_node, level => $level };
            push @nodes, $build_parent_tree->($item_id, $level + 1);
        }
        return @nodes;
    };
    my @parent_item_list = $build_parent_tree->(0, 0);


    my $all_locations_rs = $c->app->schema->resultset('Location')->search({}, { order_by => 'short_name' });

    $c->render(
        template => 'item',
        item => $item,
        locations => [ $locations_rs->all ],
        parent_item_list => \@parent_item_list,
        all_locations => [ $all_locations_rs->all ]
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

# GET /generate_barcode/*code
get('/generate_barcode/*code' => sub ($c) {
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
            $generator = SVG::Barcode::EAN13->new(lineheight => 20);
        }
        elsif ($symbology eq 'UPCA') {
            $generator = SVG::Barcode::UPCA->new(lineheight => 20);
        }
        elsif ($symbology eq 'UPCE') {
            $generator = SVG::Barcode::UPCE->new(lineheight => 20);
        }
        elsif ($symbology eq 'EAN8') {
            $generator = SVG::Barcode::EAN8->new(lineheight => 20);
        }
        elsif ($symbology eq 'Code128') {
            $generator = SVG::Barcode::Code128->new(height => 50);
        }
        elsif ($symbology eq 'QR') {
            $generator = SVG::Barcode::QRCode->new(height => 50);
        }
        return unless $generator;
        return $generator->plot($code);
    };
    if ($@ || !$svg_data) {
        $c->app->log->error("Barcode generation failed for code '$code': $@");
        return $c->reply->not_found;
    }

    $c->render(data => $svg_data, format => 'svg');
})->name('barcode_image');

# --- Location & Inventory Management ---

# GET /locations
get('/locations' => sub ($c) {
    my $locations_rs = $c->app->schema->resultset('Location')->search({}, { order_by => 'short_name' });
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

# GET /location/:id
get('/location/:id' => sub ($c) {
    my $id = $c->param('id');
    my $location = $c->app->schema->resultset('Location')->find($id);
    return $c->reply->not_found unless $location;

    my $items_in_location = $c->app->schema->resultset('Inventory')->search(
        { location_id => $id },
        {
            select   => [ 'item.id', 'item.short_description', { count => 'item_id' } ],
            as       => [qw/item_id short_description count/],
            join     => 'item',
            group_by => [ 'item.id', 'item.short_description' ],
            order_by => { -asc => 'item.short_description' }
        }
    );

    my $all_items_rs = $c->app->schema->resultset('Item')->search(
        {},
        { order_by => { -asc => 'me.short_description' } }
    );

    $c->render(
        template => 'location',
        location => $location,
        items_in_location => [ $items_in_location->all ],
        all_items => [ $all_items_rs->all ]
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
        .container { padding: 2rem; max-width: 1200px; margin: auto; }
        h1, h2, h3 { border-bottom: 2px solid #ddd; padding-bottom: 10px; color: #333; }
        table { border-collapse: collapse; width: 100%; margin-top: 1rem; background: white; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        form { display: grid; gap: 1rem; background: white; padding: 1.5rem; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-top: 1rem; }
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
    </style>
</head>
<body>
    <nav>
        <a href="<%= url_for('/') %>">Dashboard</a>
        <a href="<%= url_for('items') %>">Items</a>
        <a href="<%= url_for('gtins') %>">Barcodes</a>
        <a href="<%= url_for('locations') %>">Locations</a>
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
                <li style="padding-left: <%= $level * 20 %>px;">
                    <a href="<%= url_for('item_show', {id => $node->{item}->id}) %>"><%= $node->{item}->short_description %></a>
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
        <table>
            <thead><tr><th>ID</th><th>Short Description</th><th>Long Description</th><th>Parent Item</th></tr></thead>
            <tbody>
            % for my $item (@$items) {
                <tr>
                    <td><%= $item->id %></td>
                    <td><a href="<%= url_for('item_show', {id => $item->id}) %>"><%= $item->short_description %></a></td>
                    <td><%= $item->description %></td>
                    <td>
                        % if (my $parent = $item->parent) {
                            <a href="<%= url_for('item_show', {id => $parent->id}) %>"><%= $parent->short_description %></a>
                        % } else {
                            -
                        % }
                    </td>
                </tr>
            % }
            </tbody>
        </table>
    </div>
    <div class="panel">
        <h2>Add New Item</h2>
        <form action="<%= url_for('item_create') %>" method="POST">
            <label for="short_description">Short Description:</label>
            <input type="text" name="short_description" required>
            <label for="parent_id">Parent Item (Optional):</label>
            <select name="parent_id">
                <option value="">-- None --</option>
                % for my $item_node (@$items) {
                    <option value="<%= $item_node->id %>"><%= $item_node->description || $item_node->short_description %></option>
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
            </tr>
        </thead>
        <tbody>
        % for my $gtin (@$gtins) {
            <tr>
                <td><%= $gtin->gtin %></td>
                <td>
                    <img src="<%= url_for('barcode_image', {code => $gtin->gtin}) %>" alt="Barcode for <%= $gtin->gtin %>" height="50">
                </td>
                <td>
                    % if (my $item = $gtin->item) {
                        <a href="<%= url_for('item_show', {id => $item->id}) %>"><%= $item->short_description %></a>
                    % } else {
                        <span style="color: #999;">Not linked</span>
                    % }
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
            <label for="description">Long Description:</label>
            <input type="textarea" name="description" value="<%= $item->description %>">
            <label for="parent_id">Parent Item:</label>
            <select name="parent_id">
                <option value="">-- None --</option>
                % for my $node (@$parent_item_list) {
                    % my $p_item = $node->{item};
                    % my $indent = '&nbsp;&nbsp;' x $node->{level};
                    <option value="<%= $p_item->id %>" <%= ($item->parent_id && $item->parent_id == $p_item->id) ? 'selected' : '' %>><%= Mojo::ByteStream->new($indent) %><%= $p_item->short_description %></option>
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
        <table>
            <thead><tr><th>GTIN</th><th>Barcode</th><th>Action</th></tr></thead>
            % for my $gtin ($item->gtins) {
            <tr>
                <td><%= $gtin->gtin %></td>
                <td><img src="<%= url_for('barcode_image', {code => $gtin->gtin}) %>" alt="Barcode for <%= $gtin->gtin %>" height="50"></td>
                <td>
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
                <td><%= $loc->get_column('location_name') %></td>
                <td><%= $loc->get_column('count') %></td>
            </tr>
            % }
        </table>
        <h3>Adjust Inventory</h3>
        <form action="<%= url_for('inventory_adjust') %>" method="POST">
            <input type="hidden" name="item_id" value="<%= $item->id %>">
            <label for="location_id">Location:</label>
            <select name="location_id">
                % for my $loc (@$all_locations) {
                <option value="<%= $loc->id %>"><%= $loc->full_name %></option>
                % }
            </select>
            <div style="display: flex; gap: 1rem;">
                <button type="submit" name="action" value="add">Add One</button>
                <button type="submit" name="action" value="remove" class="delete">Remove One</button>
            </div>
        </form>
    </div>
</div>

@@ locations.html.ep
% layout 'layout';
<h1>Locations</h1>
<div class="grid">
    <div class="panel">
        <h2>All Locations</h2>
        <table>
            <thead><tr><th>ID</th><th>Short Name</th><th>Full Name</th><th>Actions</th><th>Codes</th></tr></thead>
            <tbody>
            % for my $loc (@$locations) {
                <tr>
                    <td><%= $loc->id %></td>
                    <td><%= $loc->short_name %></td>
                    <td><%= $loc->full_name %></td>
                    <td>
                        <a href="<%= url_for('location_show', {id => $loc->id}) %>">View/Manage</a>
                    </td>
                    <td>
                        <div style="display: flex; gap: 1em; margin-top: 0.5em;">
                            <div>
                                <img src="<%= url_for('barcode_image', {code => 'inventory://' . $loc->short_name . '/add'}) %>" alt="QR Code for adding to <%= $loc->short_name %>" width="80" height="80">
                            </div>
                            <div>
                                <img src="<%= url_for('barcode_image', {code => 'inventory://' . $loc->short_name . '/remove'}) %>" alt="QR Code for removing from <%= $loc->short_name %>" width="80" height="80">
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

@@ location.html.ep
% layout 'layout';
<h1>Location: <%= $location->full_name %></h1>

<div class="grid">
    <div class="panel">
        <h2>Items in this Location</h2>
        % if (@$items_in_location) {
            <table>
                <thead><tr><th>Item</th><th>Count</th></tr></thead>
                <tbody>
                % for my $item (@$items_in_location) {
                    <tr>
                        <td><a href="<%= url_for('item_show', {id => $item->get_column('item_id')}) %>"><%= $item->get_column('short_description') %></a></td>
                        <td><%= $item->get_column('count') %></td>
                    </tr>
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
                % for my $item_node (@$all_items) {
                    <option value="<%= $item_node->id %>"><%= $item_node->description || $item_node->short_description %></option>
                % }
            </select>
            <div style="display: flex; gap: 1rem;">
                <button type="submit" name="action" value="add">Add One</button>
                <button type="submit" name="action" value="remove" class="delete">Remove One</button>
            </div>
        </form>
    </div>
</div>
