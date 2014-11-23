#! /usr/bin/perl

use warnings;
use strict;
use 5.010;
use Carp;

my @elements = ();
my $current_element = undef;
my @guide_colors = qw/Black Blue Fuchsia Gray Green Maroon Navy Olive Purple Red Teal/;
my @current_guide_colors;

sub get_mil {
	my $s = shift;
	for($s) {
		if(/^(.*?)\s*mil$/) {
			return $1 + 0;
		}
		else {
			return $_ / 100;
		}
	}
}

while(<>) {
	if(defined $current_element) {
		my $name = $current_element->{name};
		my $lines = $current_element->{lines};

		if(/^\s*\)\s*$/) {
			$current_element = undef;
		}
		elsif(/^\s*Pad\s*\[(.*?)\]\s*$/) {
			my @params = split(/\s+/, $1);
			my($x0,$y0,$x1,$y1,$r2) = map { get_mil($_) } @params[0..4];

			if(not @current_guide_colors) {
				@current_guide_colors = @guide_colors;
			}

			push @$lines, {
				from => { x => $x0, y => $y0, cap => "in" },
				to => { x => $x1, y => $y1, cap => "out" },
				guide_color => shift(@current_guide_colors),
			};
		}
	}
	else {
		if(/^\s*Element\s*\[\s*""\s+""\s+"(.*?)"/) {
			$current_element = { name => $1, lines => [] };
			@current_guide_colors = ();
			push @elements, $current_element;
		}
	}
}

use JSON;
print JSON->new->utf8->pretty->encode(\@elements);

