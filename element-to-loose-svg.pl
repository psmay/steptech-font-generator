#! /usr/bin/perl

use warnings;
use strict;
use 5.010;
use Carp;

use Math::Trig 'rad2deg';

my $stroke_width = 100;
my $page_width = $stroke_width / 2;
my $page_height = 1000;
my $baseline_x = 0;
my $baseline_y = 800;


sub get_cap_0 {
	my($cap0, $shear0) = @_;

	if($cap0 eq 'none') {
		return 'M 0 1 l 0 -2';
	}
	elsif($cap0 eq 'shear') {
		my $ashear0 = -$shear0;
		return "M $ashear0 1 L $shear0 -1";
	}
	elsif($cap0 eq 'c') {
		return "M 0 1 a 1,1 0 1,1 0 -2";
	}
	elsif($cap0 eq 'out') {
		return "M 0 1 l -0.5 -1 l 0.5 -1";
	}
	elsif($cap0 eq 'in') {
		return "M 0 1 l -0.5 0 l 0.5 -1 l -0.5 -1 l 0.5 0";
	}	
	elsif($cap0 eq 's') {
		return "M -1 1 l 0 -2";
	}
	elsif($cap0 eq 'cs') {
		return "M 0 1 a 1,1 0 0,1 -1 -1 l 0 -1 l 1 0";
	}
	elsif($cap0 eq 'sc') {
		return "M -1 1 l 0 -1 a 1,1 0 0,1 1 -1";
	}
}

sub get_cap_1 {
	my($cap1, $shear1, $length) = @_;

	if($cap1 eq 'none') {
		return "L $length -1 L $length 1";
	}
	elsif($cap1 eq 'shear') {
		my $topx = $length + $shear1;
		my $botx = $length - $shear1;
		return "L $topx -1 L $botx 1";
	}
	elsif($cap1 eq 'c') {
		return "L $length -1 a 1,1 0 1,1 0 2";
	}
	elsif($cap1 eq 'out') {
		return "L $length -1 l 0.5 1 l -0.5 1";
	}
	elsif($cap1 eq 'in') {
		return "L $length -1 l 0.5 0 l -0.5 1 l 0.5 1 l -0.5 0";
	}
	elsif($cap1 eq 's') {
		my $realx = $length + 1;
		return "L $realx -1 l 0 2";
	}
	elsif($cap1 eq 'cs') {
		return "L $length -1 a 1,1 0 0,1 1 1 l 0 1 l -1 0";
	}
	elsif($cap1 eq 'sc') {
		my $topx = $length + 1;
		return "L $topx -1 l 0 1 a 1,1 0 0,1 -1 1";
	}
}

sub place_stroke {
	my %opt = @_;

	$opt{cap0} //= 'in';
	$opt{shear0} //= 0;
	$opt{cap1} //= 'out';
	$opt{shear1} //= 0;
	$opt{fill} //= 'red';
	$opt{radius} //= 1;

	$opt{dotdir} //= 'x';
	$opt{dotdir} = 0 if $opt{dotdir} eq 'x';
	$opt{dotdir} = -90 if $opt{dotdir} eq 'y';

	# Translate so x0,y0 = 0,0
	my $ex = $opt{x1} - $opt{x0};
	my $ey = $opt{y1} - $opt{y0};

	# Scale so that 1.0 represents r
	my $scale = $opt{radius};
	$ex /= $scale;
	$ey /= $scale;

	# Rotate so that segment points +x
	my $rot = 0;
	my $length;

	if($ex != 0 or $ey != 0) {
		# Since our +x and +y aren't the same as the mathematical variety, we'll
		# tilt our heads to the right and pretend that our +x is math +y and our
		# +y is math -x. Now the segment must be turned to point +y.
		$rot = -rad2deg(atan2(-$ey,$ex));
		$length = sqrt(($ex*$ex) + ($ey*$ey));
	} else {
		# This is a dot, not a line.
		# The dotdir parameter is used to give us a hint which direction the
		# dot is facing for capping purposes.
		$rot = 0 - $opt{dotdir};
		$length = 0;
	}


	# We transform so that
	# 	x0,y0 are at 0,0 (translate)
	#	y1 = y0 (rotate)
	#	1 = r (scale)

	my $cmd0 = get_cap_0($opt{cap0}, $opt{shear0});
	my $cmd1 = get_cap_1($opt{cap1}, $opt{shear1}, $length);

	return qq{ 
		<path transform="translate($baseline_x,$baseline_y) translate($opt{x0},$opt{y0}) scale($scale) rotate($rot)"
			d="M 0 0 $cmd0 $cmd1 z" style="stroke:none; fill:$opt{fill}; opacity:0.5"/>
	};
}


sub draw_element_lines
{
	my @lines = @_;
	my @out = ();

	for my $line (@lines) {
		# Some lines are only for spacing purposes
		my $draw = $line->{draw} // 1;
		next unless $draw;

		my $from = $line->{from};
		my $to = $line->{to};

		push @out, place_stroke(
			x0 => $from->{x},
			y0 => $from->{y},
			cap0 => $from->{cap},
			shear0 => $from->{shear},
			x1 => $to->{x},
			y1 => $to->{y},
			cap1 => $to->{cap},
			shear1 => $to->{shear},
			fill => lc ($line->{guide_color} // ""),
			radius => $stroke_width / 2,
			dotdir => $line->{dotdir},
		);
	}

	return join("", @out);
}

sub get_generic_bounds
{
	my $radius = shift;
	my @lines = @_;

	my $left = 0;
	my $top = 0;
	my $right = 0;
	my $bottom = 0;

	for my $line (@lines) {
		# Some lines don't get counted when spacing
		my $spread = $line->{spread} // 1;
		next unless $spread;

		for my $endpoint ($line->{from}, $line->{to}) {
			my $pleft = $endpoint->{x} - $radius;
			my $pright = $endpoint->{x} + $radius;
			my $ptop = $endpoint->{y} - $radius;
			my $pbottom = $endpoint->{y} + $radius;
			$left = $pleft if $left > $pleft;
			$right = $pright if $right < $pright;
			$top = $ptop if $top > $ptop;
			$bottom = $pbottom if $bottom < $pbottom;
		}
	}

	return ($left, $top, $right, $bottom);
}

sub get_element_bounds
{
	return get_generic_bounds($stroke_width/2, @_);
}

sub dmin {
	my $current = undef;
	for(@_) {
		next unless defined $_;
		$current = $_ if (!defined($current) || ($_ < $current));
	}
	$current;
}

sub dmax {
	my $current = undef;
	for(@_) {
		next unless defined $_;
		$current = $_ if (!defined($current) || ($_ > $current));
	}
	$current;
}

sub get_unzeroed_element_bounds
{
	my $radius = $stroke_width/2;
	my @lines = @_;

	my($left,$top,$right,$bottom);

	for my $line (@lines) {
		# Some lines don't get counted when spacing
		my $spread = $line->{spread} // 1;
		next unless $spread;

		for my $endpoint ($line->{from}, $line->{to}) {
			my $pleft = $endpoint->{x} - $radius;
			$left //= $pleft;
			my $pright = $endpoint->{x} + $radius;
			$right //= $pright;
			my $ptop = $endpoint->{y} - $radius;
			$top //= $ptop;
			my $pbottom = $endpoint->{y} + $radius;
			$bottom //= $pbottom;
			$left = dmin($left, $pleft);
			$right = dmax($right, $pright);
			$top = dmin($top, $ptop);
			$bottom = dmax($bottom, $pbottom);
		}
	}

	return ($left, $top, $right, $bottom);
}

# Parameter is { "glyph":{...}, "op":[[opname,...],[opname,...],...] }
sub get_compose_lines
{
	my $compose_item = shift;
	my $previous_compose_items = shift // [];
	my $element = $compose_item->{glyph} || {};
	# If a glyph is composed with spread=false, mark the resulting lines.
	my $spread = $compose_item->{spread} // 1;
	# The op point defaults to the result of bmove0
	my @op = (['bmove0'], @{ $compose_item->{op} || [] });

	my @lines = get_all_element_lines($element);
	my @h = ({});
	my $pushh = sub {
		my %new = %{$h[0]};
		unshift @h, \%new;
	};
	my $peekh = sub {
		my $count = shift;
		$count //= 1;
		if(@h < $count) {
			die "Not enough points on stack";
		}
		return @h[0 .. $count-1];
	};
	my $splh = sub {
		my $count = shift;
		$count //= 1;
		my @repl = @_;
		if(@h + @repl - $count < 1) {
			die "Not enough points left on stack";
		}
		return splice(@h, 0, $count, @repl);
	};
	my $geth = sub {
		my $index = shift;
		$index //= 0;
		return ($h[$index]{x}, $h[$index]{y});
	};
	my $seth = sub {
		my $x = shift;
		my $y = shift;
		my $index = shift;
		$index //= 0;
		$h[$index]{x} = 0 + $x;
		$h[$index]{y} = 0 + $y;
	};
	my $mvh = sub {
		my $dx = shift;
		my $dy = shift;
		my $index = shift;
		$index //= 0;
		my($x, $y) = $geth->($index);
		$seth->($x + $dx, $y + $dy);
	};
	my $get_previous_item = sub {
		my $name = shift;
		croak "Name is empty" unless defined $name;
		for(reverse @$previous_compose_items) {
			my $item_name = $_->{name};
			next unless defined $item_name;
			next unless $item_name eq $name;
			return $_;
		}
		die "Could not find previous compose item named `$name`";
	};
	my $get_previous_bounds = sub {
		my $name = shift;
		croak "Name is empty" unless defined $name;
		my $item = $get_previous_item->($name);
		return get_unzeroed_element_bounds(@{$item->{composed_lines}});
	};

	while (@op) {
		my $op = shift(@op);
		$op = [$op] unless ref $op;
		my($kw,@p) = @$op;

		my ($l, $t, $r, $b) = get_unzeroed_element_bounds(@lines);
		my $bxunit = $r - $l;
		my $byunit = $b - $t;
		say STDERR "l=$l t=$t r=$r b=$b xu=$bxunit yu=$byunit";

		if($kw eq 'push') {
			$pushh->();
		}
		elsif($kw eq 'pop') {
			$splh->(1);
		}
		elsif($kw eq 'move0') {
			$seth->(0,0);
		}
		elsif($kw eq 'moveby') {
			my($dx, $dy) = @p;
			$mvh->($dx, $dy);
			my($x,$y)=$geth->(); say STDERR "moveby moved us to $x $y";
		}
		elsif($kw eq 'moveto') {
			@op = (['move0'],['moveby',@p],@op);
		}
		elsif($kw eq 'bmove0') {
			$seth->(($l + $r) / 2, ($t + $b) / 2);
			my($x,$y)=$geth->(); say STDERR "bmove0 moved us to $x $y";
		}
		elsif($kw eq 'bmoveby') {
			my($dx, $dy) = @p;
			say STDERR "bmoveby dx=$dx dy=$dy xunit=$bxunit yunit=$byunit";
			$mvh->($bxunit * $dx, $byunit * $dy);
			my($x,$y)=$geth->(); say STDERR "bmoveby moved us to $x $y";
		}
		elsif($kw eq 'bmoveto') {
			@op = (['bmove0'],['bmoveby',@p],@op);
		}
		elsif($kw eq 'omove0') {
			my($og) = @p;
			my($ol, $ot, $or, $ob) = $get_previous_bounds->($og);
			$seth->(($ol + $or) / 2, ($ot + $ob) / 2);
		}
		elsif($kw eq 'omoveby') {
			my($og, $dx, $dy) = @p;
			my($ol, $ot, $or, $ob) = $get_previous_bounds->($og);
			$mvh->(($or - $ol) * $dx, ($ob - $ot) * $dy);
			my($x,$y)=$geth->(); say STDERR "omoveby moved us to $x $y";
		}
		elsif($kw eq 'omoveto') {
			my($og, @px) = @p;
			@op = (['omove0', $og], ['omoveby', $og, @px], @op);
		}
		elsif($kw eq 'translate') {
			my($dx, $dy) = @p;
			$dx += 0;
			$dy += 0;
			for my $line (@lines) {
				for my $endpoint ($line->{from}, $line->{to}) {
					$endpoint->{x} += $dx;
					$endpoint->{y} += $dy;
				}
			}
			$mvh->($dx, $dy);
		}
		elsif($kw eq 'ptranslate') {
			# Translate the shape the displacement between the current point and the previous point on the stack.
			# Remove the previous point.
			my($current) = $peekh->(1);
			my($cx, $cy) = $geth->(0);
			my($px, $py) = $geth->(1);
			say STDERR "ptranslate is from $px $py to $cx $cy";
			$splh->(2, $current);
			@op = (['translate', $cx - $px, $cy - $py]);
		}
		elsif($kw eq '_bscale_g0') {
			# Perform bscale about global origin rather than op point
			# (and don't touch op point)
			my($sx, $sy) = @p;
			my $reverse_lines = +($sx * $sy < 0);
			for my $line (@lines) {
				if($reverse_lines) {
					($line->{from},$line->{to}) = ($line->{to},$line->{from});
				}
				for my $endpoint ($line->{from}, $line->{to}) {
					if($reverse_lines) {
						my %revs = ( sc => 'cs', cs => 'sc' );
						my $rev = $revs{$endpoint->{cap}};
						$endpoint->{cap} = $rev if defined $rev;
					}
					$endpoint->{x} *= $sx;
					$endpoint->{y} *= $sy;
				}
			}
		}
		elsif($kw eq 'bscale') {
			# Translate to origin, scale, translate back
			my($sx, $sy) = @p;
			my($x, $y) = $geth->();
			@op = (
				['translate', -$x, -$y],
				['_bscale_g0', $sx, $sy],
				['translate', $x, $y],
				@op);
		}
		else {
			die "Don't know what to do with compose op `$kw`";
		}
	}

	if(not $spread) {
		$_->{spread} = 0 for @lines;
	}


	$compose_item->{composed_lines} = [@lines];

	return @lines;
}

sub get_all_element_lines
{
	my $element = shift;
	my $compose_list = $element->{compose} || [];
	my $element_lines = $element->{lines} || [];
	my $previous_compose_items = [];

	my @result = @$element_lines;

	for my $compose_item (@$compose_list) {
		my $caption = "Processing compose unit";
		$caption .= " $compose_item->{name}" if defined $compose_item->{name};
		say STDERR $caption;

		push @result, get_compose_lines($compose_item, $previous_compose_items);
		push @$previous_compose_items, $compose_item;
	}

	return @result;
}

sub draw_element_svg
{
	my $element = shift;
	my @out = ();

	my @element_lines = get_all_element_lines($element);

	my $ph = $page_height;
	my($left, $top, $right, $bottom) = get_element_bounds(@element_lines);
	my $pw = $page_width + $right;

	my $meta = do {
		use JSON;
		my %data = (
			width => $pw,
			height => $ph,
			stroke_width => $stroke_width,
			x => $baseline_x,
			y => $baseline_y,
			codepoint => $element->{codepoint},
			glyph_name => $element->{name}
		);
		local $_ = JSON->new->ascii->encode(\%data);
		s/--/-\\u002d/g;
		$_;
	};


	push @out, qq{
		<svg
			xmlns="http://www.w3.org/2000/svg"
			xmlns:stfg="https://github.com/psmay/steptech-font-generator/ns:stfg"
			xmlns:xlink="http://www.w3.org/1999/xlink"
			width="$pw" height="$ph"
			>
			<!--[STFGMETA[ $meta ]STFGMETA]-->
	};
	push @out, draw_element_lines(@element_lines);
	push @out, qq{
	</svg>
	};

	return join("", @out);
}

my $element;
{
	local $/;
	use JSON;
	$element = JSON->new->decode(<>);
}
print draw_element_svg($element);


