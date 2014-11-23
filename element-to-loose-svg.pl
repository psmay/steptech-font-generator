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


sub place_stroke {
	my($x0,$y0,$cap0,$shear0,$x1,$y1,$cap1,$shear1,$fill,$r) = @_;

	$cap0 //= 'none';
	$shear0 //= 0;
	$cap1 //= 'none';
	$shear1 //= 0;
	$fill //= 'red';
	$r //= 1;

	# Translate so x0,y0 = 0,0
	my $ex = $x1 - $x0;
	my $ey = $y1 - $y0;

	# Scale so that 1.0 represents r
	my $scale = $r;
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
		# This is a dot, not a line
		$length = 0;
	}


	# We transform so that
	# 	x0,y0 are at 0,0 (translate)
	#	y1 = y0 (rotate)
	#	1 = r (scale)

	my($cmd0,$cmd1);

	if($cap0 eq 'none') {
		$cmd0 = 'M 0 1 l 0 -2';
	}
	elsif($cap0 eq 'shear') {
		my $ashear0 = -$shear0;
		$cmd0 = "M $ashear0 1 L $shear0 -1";
	}
	elsif($cap0 eq 'c') {
		$cmd0 = "M 0 1 a 1,1 0 1,1 0 -2";
	}
	elsif($cap0 eq 'out') {
		$cmd0 = "M 0 1 l -0.5 -1 l 0.5 -1";
	}
	elsif($cap0 eq 'in') {
		$cmd0 = "M 0 1 l -0.5 0 l 0.5 -1 l -0.5 -1 l 0.5 0";
	}	
	elsif($cap0 eq 's') {
		$cmd0 = "M -1 1 l 0 -2";
	}
	elsif($cap0 eq 'cs') {
		$cmd0 = "M 0 1 a 1,1 0 0,1 -1 -1 l 0 -1 l 1 0";
	}
	elsif($cap0 eq 'sc') {
		$cmd0 = "M -1 1 l 0 -1 a 1,1 0 0,1 1 -1";
		#$cmd1 = "L $topx -1 l 0 1 a 1,1 0 0,1 -1 1";
	}

	if($cap1 eq 'none') {
		$cmd1 = "L $length -1 L $length 1";
	}
	elsif($cap1 eq 'shear') {
		my $topx = $length + $shear1;
		my $botx = $length - $shear1;
		$cmd1 = "L $topx -1 L $botx 1";
	}
	elsif($cap1 eq 'c') {
		$cmd1 = "L $length -1 a 1,1 0 1,1 0 2";
	}
	elsif($cap1 eq 'out') {
		$cmd1 = "L $length -1 l 0.5 1 l -0.5 1";
	}
	elsif($cap1 eq 'in') {
		$cmd1 = "L $length -1 l 0.5 0 l -0.5 1 l 0.5 1 l -0.5 0";
	}
	elsif($cap1 eq 's') {
		my $realx = $length + 1;
		$cmd1 = "L $realx -1 l 0 2";
	}
	elsif($cap1 eq 'cs') {
		$cmd1 = "L $length -1 a 1,1 0 0,1 1 1 l 0 1 l -1 0";
	}
	elsif($cap1 eq 'sc') {
		my $topx = $length + 1;
		$cmd1 = "L $topx -1 l 0 1 a 1,1 0 0,1 -1 1";
	}

	return qq{ 
		<path transform="translate($baseline_x,$baseline_y) translate($x0,$y0) scale($scale) rotate($rot)"
			d="M 0 0 $cmd0 $cmd1 z" style="stroke:none; fill:$fill; opacity:0.5"/>
	};
}


sub draw_element_lines
{
	my @lines = @_;
	my @out = ();

	for my $line (@lines) {
		my $from = $line->{from};
		my $to = $line->{to};
		my $guide_color = $line->{guide_color};
		push @out, place_stroke(
			$from->{x}, $from->{y}, $from->{cap}, $from->{shear},
			$to->{x}, $to->{y}, $to->{cap}, $to->{shear},
			$guide_color, $stroke_width/2
		);
	}

	return join("", @out);
}

sub get_element_bounds
{
	my @lines = @_;

	my $radius = $stroke_width/2;
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

sub draw_element_svg
{
	my $element = shift;
	my @out = ();

	my $ph = $page_height;
	my($left, $top, $right, $bottom) =
		get_element_bounds(@{$element->{lines}});
	my $pw = $page_width + $right;

	push @out, qq{
		<svg
			xmlns="http://www.w3.org/2000/svg"
			xmlns:xlink="http://www.w3.org/1999/xlink"
			width="$pw" height="$ph">
	};
	push @out, draw_element_lines(@{$element->{lines}});
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


