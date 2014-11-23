#! /usr/bin/perl

use warnings;
use strict;
use 5.010;
use Carp;

use JSON;
my $j = JSON->new->canonical->utf8->pretty(0);

my $out_dir = shift @ARGV;

my $elements = do {
	local $/;
	$j->decode(<>);
};

for my $element (@$elements) {
	my $path = $out_dir . '/' . $element->{name} . '.json';
	#say STDERR "Writing $path";
	open(my $fh, '>', $path) or die "Open '$path' failed: $!";
	binmode $fh;
	print $fh $j->encode($element);
	close $fh;
}
