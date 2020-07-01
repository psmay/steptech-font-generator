#! /usr/bin/perl

use warnings;
use strict;
use 5.010;
use Carp;

use ComposeRunner;

use Math::Trig 'rad2deg', 'deg2rad';
use POSIX 'ceil';

my $stroke_width = 100;
my $page_width = $stroke_width / 2;
my $page_height = 1000;
my $baseline_x = 0;
my $baseline_y = 800;


sub _rel_arc {
	my ($large_arc_flag, $x, $y) = @_;
	my $rx = 1;
	my $ry = 1;
	my $x_axis_rotation = 0;
	# large_arc_flag
	my $sweep_flag = 1;
	# x
	# y
	
	$large_arc_flag = $large_arc_flag ? 1 : 0;

	#return "a $rx $ry $x_axis_rotation $large_arc_flag $sweep_flag $x $y";
	
	my $h = _svg_arc_to_center_param(0, 0, $rx, $ry, $x_axis_rotation, $large_arc_flag, $sweep_flag, $x, $y);
	my %qrs = %$h;
	
	my ($cx, $cy) = ($qrs{cx}, $qrs{cy});
	my $start_angle = $qrs{startAngle};
	my $delta_angle = $qrs{deltaAngle};
	my $end_angle = $qrs{endAngle};
	my $clockwise = $qrs{clockwise};

	my $max_division_angle = deg2rad(15);
	my $divisions = ceil($delta_angle / $max_division_angle);

	my @segments = ();

	{
		my $angle0 = $start_angle;
		my $x0 = 0;
		my $y0 = 0;

		# l -1 -1 1 -1 

		for (1 .. $divisions) {
			my $angle1 = $start_angle + ($delta_angle * $_ / $divisions);
			
			my $x1 = $cx + cos($angle1);
			my $y1 = $cy + sin($angle1);

			push @segments, [$x0, $y0, $x1, $y1];

			$angle0 = $angle1;
			$x0 = $x1;
			$y0 = $y1;
		}
	}
	
	my @parameters;

	for my $segment (@segments) {
		my ($x0, $y0, $x1, $y1) = @$segment;
		my ($c1x, $c1y, $c2x, $c2y) = _get_control_points($cx, $cy, $x0, $y0, $x1, $y1);
		
		my $c1dx = $c1x - $x0;
		my $c1dy = $c1y - $y0;
		my $c2dx = $c2x - $x0;
		my $c2dy = $c2y - $y0;
		my $dx = $x1 - $x0;
		my $dy = $y1 - $y0;

		push @parameters, ($c1dx, $c1dy, $c2dx, $c2dy, $dx, $dy);
	}

	return "c @parameters";
}

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
		my $arc_c = _rel_arc(1, 0, -2);
		return "M 0 1 $arc_c";
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
		my $arc_cs = _rel_arc(0, -1, -1);
		return "M 0 1 $arc_cs l 0 -1 l 1 0";
	}
	elsif($cap0 eq 'sc') {
		my $arc_sc = _rel_arc(0, 1, -1);
		return "M -1 1 l 0 -1 $arc_sc";
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
		my $arc_c = _rel_arc(1, 0, 2);
		return "L $length -1 $arc_c";
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
		my $arc_cs = _rel_arc(0, 1, 1);
		return "L $length -1 $arc_cs l 0 1 l -1 0";
	}
	elsif($cap1 eq 'sc') {
		my $topx = $length + 1;
		my $arc_sc = _rel_arc(0, -1, 1);
		return "L $topx -1 l 0 1 $arc_sc";
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

	my $left;
	my $top;
	my $right;
	my $bottom;

	for my $line (@lines) {
		# Some lines don't get counted when spacing
		my $spread = $line->{spread} // 1;
		next unless $spread;

		for my $endpoint ($line->{from}, $line->{to}) {
			my $pleft = $endpoint->{x} - $radius;
			my $pright = $endpoint->{x} + $radius;
			my $ptop = $endpoint->{y} - $radius;
			my $pbottom = $endpoint->{y} + $radius;

			$left //= $pleft;
			$left = $pleft if $left > $pleft;

			$right //= $pright;
			$right = $pright if $right < $pright;

			$top //= $ptop;
			$top = $ptop if $top > $ptop;

			$bottom //= $pbottom;
			$bottom = $pbottom if $bottom < $pbottom;
		}
	}

	return ($left // 0, $top // 0, $right // 0, $bottom // 0);
}

sub get_element_bounds
{
	return get_generic_bounds($stroke_width/2, @_);
}

sub get_all_element_lines
{
	my $element = shift;
	my $stroke_radius = $stroke_width / 2;

	return ComposeRunner::_get_all_element_lines($element, $stroke_radius);
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
			glyph_name => $element->{name},
			lines => \@element_lines,
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


{
	use Math::Trig;

	sub _get_control_points {
		my ($cx, $cy, $x0, $y0, $x1, $y1) = @_;

		# Given an arc (center, first point, second point), calculates the control points for a cubic bezier
		# approximating the arc.

		# An adaptation of https://stackoverflow.com/a/59553816/279871
		# Designed only for arcs <= PI/2 = 90 degrees

		my $ax = $x0 - $cx;
		my $ay = $y0 - $cy;
		my $bx = $x1 - $cx;
		my $by = $y1 - $cy;
		my $q1 = ($ax * $ax) + ($ay * $ay);
		my $q2 = $q1 + ($ax * $bx) + ($ay * $by);
		my $k2 = 4 / 3 * (sqrt(2 * $q1 * $q2) - $q2) / (($ax * $by) - ($ay * $bx));
		my $c1x = $cx + $ax - ($k2 * $ay);
		my $c1y = $cy + $ay + ($k2 * $ax);
		my $c2x = $cx + $bx + ($k2 * $by);
		my $c2y = $cy + $by - ($k2 * $bx);
		return ($c1x, $c1y, $c2x, $c2y);
	}

	sub _svg_arc_to_center_param {
		my ($x1, $y1, $rx, $ry, $phi, $fA, $fS, $x2, $y2) = @_;

		# Given an initial point followed by the parameters for an SVG arc, determines the center, start angle, end
		# angle, delta between angles, and a clockwise flag.

		# An unembellished adaptation of
		# https://stackoverflow.com/a/12329083/279871
		# which is an implementation of an algorithm from
		# https://www.w3.org/TR/SVG11/implnote.html

		sub _2pi() { pi * 2.0 }

		sub _radian {
			my ($ux, $uy, $vx, $vy) = @_;
			my $dot = $ux * $vx + $uy * $vy;
			my $mod = sqrt(($ux * $ux + $uy * $uy) * ($vx * $vx + $vy * $vy));
			my $rad = acos($dot / $mod);
			if($ux * $vy - $uy * $vx < 0.0) {
				$rad = -$rad;
			}
			return $rad;
		}

		if ($rx < 0) { $rx = -$rx; }
		if ($ry < 0) { $ry = -$ry; }

		if ($rx == 0.0 || $ry == 0.0) { # invalid arguments
			croak '$rx and $ry can not be 0';
		}

		my $s_phi = sin($phi);
		my $c_phi = cos($phi);
		my $hd_x = ($x1 - $x2) / 2.0; # half diff of x
		my $hd_y = ($y1 - $y2) / 2.0; # half diff of y
		my $hs_x = ($x1 + $x2) / 2.0; # half sum of x
		my $hs_y = ($y1 + $y2) / 2.0; # half sum of y

		# F6.5.1
		my $x1_ = $c_phi * $hd_x + $s_phi * $hd_y;
		my $y1_ = $c_phi * $hd_y - $s_phi * $hd_x;

		# F.6.6 Correction of out-of-range radii
		# Step 3: Ensure radii are large enough
		my $lambda = ($x1_ * $x1_) / ($rx * $rx) + ($y1_ * $y1_) / ($ry * $ry);
		if ($lambda > 1) {
			$rx = $rx * sqrt($lambda);
			$ry = $ry * sqrt($lambda);
		}

		my $rxry = $rx * $ry;
		my $rxy1_ = $rx * $y1_;
		my $ryx1_ = $ry * $x1_;
		my $sum_of_sq = $rxy1_ * $rxy1_ + $ryx1_ * $ryx1_; # sum of square
		if (!$sum_of_sq) {
			croak 'start point can not be same as end point';
		}
		my $coe = sqrt(abs(($rxry * $rxry - $sum_of_sq) / $sum_of_sq));
		if ($fA == $fS) { $coe = -$coe; }

		# F6.5.2
		my $cx_ = $coe * $rxy1_ / $ry;
		my $cy_ = -$coe * $ryx1_ / $rx;

		# F6.5.3
		my $cx = $c_phi * $cx_ - $s_phi * $cy_ + $hs_x;
		my $cy = $s_phi * $cx_ + $c_phi * $cy_ + $hs_y;

		my $xcr1 = ($x1_ - $cx_) / $rx;
		my $xcr2 = ($x1_ + $cx_) / $rx;
		my $ycr1 = ($y1_ - $cy_) / $ry;
		my $ycr2 = ($y1_ + $cy_) / $ry;

		# F6.5.5
		my $startAngle = _radian(1.0, 0.0, $xcr1, $ycr1);

		# F6.5.6
		my $deltaAngle = _radian($xcr1, $ycr1, -$xcr2, -$ycr2);
		while ($deltaAngle > _2pi) { $deltaAngle -= _2pi; }
		while ($deltaAngle < 0.0) { $deltaAngle += _2pi; }
		if (not $fS) { $deltaAngle -= _2pi; }
		my $endAngle = $startAngle + $deltaAngle;
		while ($endAngle > _2pi) { $endAngle -= _2pi; }
		while ($endAngle < 0.0) { $endAngle += _2pi; }

		return { # $cx, $cy, $startAngle, $deltaAngle
			cx => $cx,
			cy => $cy,
			startAngle => $startAngle,
			deltaAngle => $deltaAngle,
			endAngle => $endAngle,
			clockwise => !!$fS,
		};
	}

}









my $element;
{
	local $/;
	use JSON;
	$element = JSON->new->decode(<>);
}
print draw_element_svg($element);


