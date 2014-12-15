
package ComposeRunner;

use warnings;
use strict;
use Carp;
use 5.010;

use Storable 'dclone';

# undef-skipping min and max

sub _dmin {
	my $result;
	for(@_) {
		next unless defined;
		$result //= $_;
		$result = $_ if $_ < $result;
	}
	$result;
}

sub _dmax {
	my $result;
	for(@_) {
		next unless defined;
		$result //= $_;
		$result = $_ if $_ > $result;
	}
	$result;
}

sub _get_all_element_lines {
	my $element = shift;
	my $stroke_radius = shift;
	my $compose_list = $element->{compose} || [];
	my $element_lines = $element->{lines} || [];
	my $named_items = {};

	my @result = @$element_lines;

	for my $compose_item (@$compose_list) {
		my $cr = new ComposeRunner $compose_item, $stroke_radius,
			named_items => $named_items;
		$cr->run_item_ops;
		my %results = $cr->get_results;
		$named_items = $results{named_items};

		push @result, @{ $results{lines} };
	}

	return @result;
}


# Given a number of boxes, return the smallest box containing them all.
sub _superbox {
	my @bounds = @_;
	my($minx,$miny,$maxx,$maxy);
	while(@bounds) {
		my($minxn,$minyn,$maxxn,$maxyn) = splice(@bounds, 0, 4);
		$minx = _dmin($minx, $minxn);
		$miny = _dmin($miny, $minyn);
		$maxx = _dmax($maxx, $maxxn);
		$maxy = _dmax($maxy, $maxyn);
	}
	return ($minx, $miny, $maxx, $maxy);
}

# Given a center and a radius, return the smallest box containing the circle.
sub _radiusbox {
	my($x, $y, $radius) = @_;
	return ($x - $radius, $y - $radius, $x + $radius, $y + $radius);
}

# Given a radius and a list of lines, return the smallest box containing a
# circle of the radius around all endpoints of all lines. Lines whose
# `spread` property is false are omitted. If there are no lines in the
# calculation, the result is (0,0,0,0).
sub _get_generic_bounds {
	my $radius = shift;
	my @lines = @_;

	my @sb;

	for my $line (@lines) {
		my $affects_bounding_box = $line->{spread} // 1;
		next unless $affects_bounding_box;

		for my $point ($line->{from}, $line->{to}) {
			@sb = _superbox(@sb, _radiusbox($point->{x}, $point->{y}, $radius));
		}
	}

	return @sb ? @sb : (0,0,0,0);
}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = bless {}, $class;
	my $orig_compose_item = shift;
	my $radius = shift;
	my %args = @_;

	$self->{stroke_radius} = $radius + 0;
	$self->{named_items} = { %{ $args{named_items} // {} } };

	my $compose_item = dclone($orig_compose_item);
	my $element = $compose_item->{glyph} || {};
	$self->{name} = $compose_item->{name};
	$self->{spread} = $compose_item->{spread} // 1;
	$self->{ops} = [['localmove0'], @{ $compose_item->{op} || [] }];
	$self->{ops_have_run} = 0;

	$self->{anchors} = $element->{anchors} || {};
	$self->{lines} = [ _get_all_element_lines($element, $radius) ];
	$self->{points} = [[0,0]];

	return $self;
}

sub run_item_ops {
	my $self = shift;
	croak "Already ran item ops" if $self->{ops_have_run};
	$self->{ops_have_run} ||= !!1;
	my $ops = $self->{ops};
	use Data::Dumper;
	for my $op (@$ops) {
		$op = [$op] unless ref $op;
		$self->_run_op(@$op);
	}

	my $a = $self->{anchors};
	my $l = dclone($self->{lines});
	if(not $self->{spread}) {
		$_->{spread} = !!0 for @$l;
	}
	my $ii = $self->{named_items};
	if(defined $self->{name}) {
		$ii = { %$ii };
		$ii->{$self->{name}} = $self;
	}

	$self->{result} = {
		anchors => $a,
		lines => $l,
		named_items => $ii
	};
}

sub get_results {
	my $self = shift;
	$self->run_item_ops if not $self->{ops_have_run};
	return %{$self->{result}};
}

sub _run_op {
	my $self = shift;
	my $name = shift;
	my $method_name = "op_$name";
	if($self->can($method_name)) {
		return $self->$method_name(@_);
	}
	else {
		croak "Unknown compose op `$name`";
	}
}

sub _lines {
	my $lines = $_[0]->{lines};
	croak "Current lines value is not array ref"
		unless +( ref($lines) and ref($lines) eq 'ARRAY' );
	return $_[0]->{lines};
}

sub _anchors {
	return $_[0]->{anchors};
}

my %_default_anchors = (
	left =>			[ -0.5, 0    ],
	topleft =>		[ -0.5, -0.5 ],
	top =>			[ 0   , -0.5 ],
	topright =>		[ +0.5, -0.5 ],
	right =>		[ +0.5, 0    ],
	bottomright =>	[ +0.5, +0.5 ],
	bottom =>		[ 0   , +0.5 ],
	bottomleft =>	[ -0.5, +0.5 ],
	center =>		[ 0   , 0    ],
);

sub _anchor {
	my $self = shift;
	my $name = shift;
	my $anchor = $self->_anchors->{$name};
	if(not defined $anchor) {
		my $lc = $_default_anchors{$name};
		croak "Anchor named `$name` does not exist" unless defined $lc;
		my($x, $y) = $self->get_local_coords(@{$lc});
		$anchor = { x => $x, y => $y };
	}
	return ($anchor->{x}, $anchor->{y});
}

sub _get_point {
	my $self = shift;
	my $index = shift;
	$index //= 0;
	my $p = $self->{points};
	if(not exists $p->[$index]) {
		croak "Point at index $index does not exist";
	}
	return @{$p->[$index]};
}

sub _set_point {
	my $self = shift;
	my $x = shift;
	my $y = shift;
	my $index = shift;
	$index //= 0;
	my $p = $self->{points};
	if(not exists $p->[$index]) {
		croak "Point at index $index does not exist";
	}
	@{$p->[$index]} = ($x + 0, $y + 0);
}

sub _dup_point {
	my $self = shift;
	my @here = $self->_get_point;
	my $p = $self->{points};
	unshift @$p, \@here;
}

sub _pop_point {
	my $self = shift;
	my $count = shift;
	$count //= 1;
	my @repl = @_;

	my $p = $self->{points};
	if(@$p < $count) {
		croak "Cannot pop this many points";
	}
	if(@$p + @repl - $count < 1) {
		croak "Cannot pop last point without replacement";
	}

	my @truerepl;
	for(@repl) {
		my($x, $y) = @$_;
		push @truerepl, [$x + 0, $y + 0];
	}
	return splice(@$p, 0, $count, @truerepl);
}

sub get_point {
	my $self = shift;
	my $index = shift;
	return $self->_get_point($index);
}

sub translate_coords {
	my $self = shift;
	my $dx = shift;
	my $dy = shift;
	my $originx = shift;
	my $originy = shift;
	$originx //= 0;
	$originy //= 0;
	my $x = 0 + $originx + $dx;
	my $y = 0 + $originy + $dy;
	return ($x, $y);
}

sub set_point {
	my $self = shift;
	my $x = shift;
	my $y = shift;
	my $index = shift;
	$self->_set_point($x, $y, $index);
}

sub set_point_rel {
	my $self = shift;
	my $dx = shift;
	my $dy = shift;
	my $index = shift;
	my($x, $y) = $self->get_point($index);
	$self->_set_point($self->translate_coords($dx, $dy, $x, $y), $index);
}

sub element_bounds_and_units {
	my $self = shift;
	my $stroke_radius = $self->{stroke_radius};
	my @lines = @{ $self->_lines };
	my ($l, $t, $r, $b) = _get_generic_bounds($stroke_radius, @lines);
	my $xu = $r - $l;
	my $yu = $b - $t;
	return ($l, $t, $r, $b, $xu, $yu);
}

sub get_local_coords {
	my $self = shift;
	my $x = shift;
	my $y = shift;
	my $x0 = shift;
	my $y0 = shift;

	my ($l, $t, $r, $b, $xu, $yu) = $self->element_bounds_and_units;
	$x0 //= ($l + $r) / 2;
	$y0 //= ($t + $b) / 2;
	return ($x0 + ($xu * $x), $y0 + ($yu * $y));
}

sub op_push {
	my $self = shift;
	$self->_dup_point;
}

sub op_pop {
	my $self = shift;
	$self->_pop_point;
}

sub op_move0 {
	my $self = shift;
	$self->set_point(0, 0);
}

sub op_moveby {
	my $self = shift;
	my $dx = shift;
	my $dy = shift;
	$self->set_point_rel($dx, $dy);
}

sub op_moveto {
	my $self = shift;
	my $x = shift;
	my $y = shift;
	$self->set_point($x, $y);
}

sub op_movetoanchor {
	$_[0]->_rel_movetoanchor(@_);
}

sub _rel_move0 {
	my $self = shift;
	my $coord_source = shift;
	$self->_rel_moveto($coord_source, 0, 0);
}

sub _rel_moveto {
	my $self = shift;
	my $coord_source = shift;
	my $lx = shift;
	my $ly = shift;
	my($x, $y) = $coord_source->get_local_coords($lx, $ly);
	$self->set_point($x, $y);
}

sub _rel_moveby {
	my $self = shift;
	my $coord_source = shift;
	my $ldx = shift;
	my $ldy = shift;
	my($x0, $y0) = $self->get_point;
	$self->set_point($coord_source->get_local_coords($ldx, $ldy, $x0, $y0));
}

sub _rel_movetoanchor {
	my $self = shift;
	my $anchor_source = shift;
	my $anchor_name = shift;
	my($x, $y) = $anchor_source->_anchor($anchor_name);
	$self->set_point($x, $y);
}

sub op_localmove0 {
	$_[0]->_rel_move0(@_);
}

sub op_localmoveto {
	$_[0]->_rel_moveto(@_);
}

sub op_localmoveby {
	$_[0]->_rel_moveby(@_);
}

sub _named_item {
	my $self = shift;
	my $item_name = shift;
	my $item = $self->{named_items}{$item_name};
	croak "Could not find named item `$item_name`" unless defined $item;
	return $item;
}

sub op_itemmove0 {
	my $self = shift;
	my $item = $self->_named_item(shift);
	$self->_rel_move0($item, @_);
}

sub op_itemmoveto {
	my $self = shift;
	my $item = $self->_named_item(shift);
	$self->_rel_moveto($item, @_);
}

sub op_itemmoveby {
	my $self = shift;
	my $item = $self->_named_item(shift);
	$self->_rel_moveby($item, @_);
}

sub op_itemmovetoanchor {
	my $self = shift;
	my $item = $self->_named_item(shift);
	$self->_rel_movetoanchor($item, @_);
}

sub _translate_by {
	my $self = shift;
	my($dx, $dy) = @_;
	$dx += 0;
	$dy += 0;

	my @pointlike;

	my $anchors = $self->_anchors;
	my $lines = $self->_lines;

	push @pointlike, (values %$anchors);
	for my $line (@$lines) {
		push @pointlike, $line->{from}, $line->{to};
	}

	for(@pointlike) {
		$_->{x} += $dx;
		$_->{y} += $dy;
	}
}

# The absolute equivalent would be called "move"
sub op_translate {
	my $self = shift;
	my($dx, $dy) = @_;
	$self->_translate_by($dx, $dy);
}

# Translate so that what is currently at [0] will be at [1] instead.
sub _translate_point_to_point {
	my $self = shift;
	my($x0,$y0,$x1,$y1) = @_;
	my $dx = $x1 - $x0;
	my $dy = $y1 - $y0;
	$self->op_translate($dx, $dy);
}

# To use:
# 1. Move to the reference point.
# 2. Push.
# 3. Move to the destination point.
# 4. Use this command. The reference point is removed from the stack.
sub op_translatefromprevious {
	my $self = shift;
	my @from = $self->get_point(1);
	my @to = $self->get_point(0);
	$self->_translate_point_to_point(@from, @to);
	$self->_pop_point(2, \@to);
}


# To use:
# 1. Move to the destination.
# 2. Push.
# 3. Move to the reference point.
# 4. Use this command. The reference point is removed from the stack.
sub op_translatetoprevious {
	my $self = shift;
	my @from = $self->get_point(0);
	my @to = $self->get_point(1);
	$self->_translate_point_to_point(@from, @to);
	$self->_pop_point(1);
}

# Scale about the global origin.
# sx, sy = 1, 1 leaves the image exactly as-is.
# -1, -1 is equivalent to a 180-degree rotation.
# Negative values reflect the image about the axes.
# Absolute values other than 1 deform the image.
sub _scale_about_origin
{
	my $self = shift;
	my $sx = shift;
	my $sy = shift;

	# If there is reflection in one axis but not both, asymmetrical properties of the lines must be flipped.
	my $flip_lines = +($sx * $sy < 0);

	my @pointlike;

	push @pointlike, (values %{$self->_anchors});

	for my $line (@{$self->_lines}) {
		my @p = ($line->{from}, $line->{to});

		if($flip_lines) {
			($line->{to},$line->{from}) = @p;
			for(@p) {
				my %cap_reversals = (sc => 'cs', cs => 'sc');
				my $reversal = $cap_reversals{$_->{cap}};
				$_->{cap} = $reversal if defined $reversal;
			}
		}
		push @pointlike, @p;
	}

	for(@pointlike) {
		$_->{x} *= $sx;
		$_->{y} *= $sy;
	}
}

sub _scale_about_point
{
	my $self = shift;
	my $sx = shift;
	my $sy = shift;
	my $x0 = shift;
	my $y0 = shift;

	# Translate reference point to 0, 0
	$self->_translate_by(-$x0, -$y0);
	# Scale about 0, 0
	$self->_scale_about_origin($sx, $sy);
	# Translate reference point back
	$self->_translate_by($x0, $y0);
}

# The absolute equivalent would be called "resize"
sub op_scale
{
	my $self = shift;
	my($sx, $sy) = @_;
	my($x0, $y0) = $self->get_point;
	$self->_scale_about_point($sx, $sy, $x0, $y0);
}

# Diacritic align, a common use case for composition
# Name the compose item for the letter "base".
# Name an anchor on the diacritic "d-BASEANCHORNAME".
# Name an anchor on the base "BASEANCHORNAME" (or use one of the
#	autogenerated names, like "top").
# Do ["aligndia", "BASEANCHORNAME"] in the diacritic's compose item.
# The diacritic is translated such that the two anchors refer to the same
# point.
sub op_aligndia
{
	my $self = shift;
	my $point_name = shift;
	$self->op_push;
	$self->op_movetoanchor("d-$point_name");
	$self->op_push;
	$self->op_itemmovetoanchor("base", "$point_name");
	$self->op_translatefromprevious;
	$self->op_pop;
}

1;
