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

# Parameter is { "glyph":{...}, "op":[[opname,...],[opname,...],...] }
sub get_compose_lines
{
	my $compose_item = shift;
	my $element = $compose_item->{glyph} || {};
	# The op point defaults to the result of bmove0
	my @op = (['bmove0'], @{ $compose_item->{op} || [] });

	my @lines = get_all_element_lines($element);
	my $op_x;
	my $op_y;

	while (@op) {
		my $op = shift(@op);
		$op = [$op] unless ref $op;
		my($kw,@p) = @$op;

		my ($l, $t, $r, $b) = get_element_bounds(@lines);
		my $bxunit = $r - $l;
		my $byunit = $b - $t;

		if($kw eq 'move0') {
			$op_x = 0;
			$op_y = 0;
		}
		elsif($kw eq 'moveby') {
			my($dx, $dy) = @p;
			$op_x += 0 + $dx;
			$op_y += 0 + $dy;
		}
		elsif($kw eq 'moveto') {
			@op = (['move0'],['moveby',@p],@op);
		}
		elsif($kw eq 'bmove0') {
			$op_x = ($l + $r) / 2;
			$op_y = ($t + $b) / 2;
		}
		elsif($kw eq 'bmoveby') {
			my($dx, $dy) = @p;
			$op_x += 0 + ($bxunit * $dx);
			$op_y += 0 + ($byunit * $dy);
		}
		elsif($kw eq 'bmoveto') {
			@op = (['bmove0'],['moveby',@p],@op);
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
			$op_x += $dx;
			$op_y += $dy;
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
			@op = (
				['translate', -$op_x, -$op_y],
				['_bscale_g0', $sx, $sy],
				['translate', $op_x, $op_y],
				@op);
		}
		else {
			die "Don't know what to do with compose op `$kw`";
		}
	}

	return @lines;
}

sub get_all_element_lines
{
	my $element = shift;
	my $compose_list = $element->{compose} || [];
	my $element_lines = $element->{lines} || [];

	my @result = @$element_lines;

	for my $compose_item (@$compose_list) {
		push @result, get_compose_lines($compose_item);
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


