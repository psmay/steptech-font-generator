#! /usr/bin/perl

# This script forces an order of keys conducive to an understandable and
# easily edited master, and reindents using tabs.
#
# The key order is forced by prefixing all keys in the entire structure with
# `{ORDERED_KEY:dddddddd}`, where `dddddddd` is eight decimal digits. The
# number used depends on the key's position in a list; if it is not in the
# list, it is given the number after the highest number for the list,
# whereby the remaining keys are sorted lexicographically. After the
# structure is formatted, the prefixes are stripped from the result.

use warnings;
use strict;
use 5.010;
use Carp;

use JSON;

my $j = JSON->new->utf8->pretty->relaxed->canonical;

my @key_order = qw/
	name
	compose
	lines
	anchors

	glyph
	op

	draw
	guide_color
	from
	to

	x
	y
	cap
	shear
/;

my %map = ();
my $last_index = 1;

for(@key_order) {
	$map{$_} = $last_index++;
}

sub convert_item {
	my $item = shift;
	if(ref $item) {
		if(ref($item) eq 'ARRAY') {
			return convert_list($item);
		}
		elsif(ref($item) eq 'HASH') {
			return convert_object($item);
		}
	}
	return $item;
}

sub convert_list {
	my $list = shift;
	my @out;
	for(@$list) {
		push @out, convert_item($_);
	}
	return \@out;
}

sub convert_object {
	my $object = shift;
	my %out;
	for(keys %$object) {
		my $i = $map{$_};
		$i = $last_index unless defined $i;
		my $k = sprintf('{ORDERED_KEY:%08d}%s', $i, $_);
		$out{$k} = convert_item($object->{$_});
	}
	return \%out;
}

sub replace_indents {
	my $spaces = shift;
	$spaces =~ s/(   )/\t/sg;
	return $spaces;
}

my $converted = do {
	local $/;
	my $top = $j->decode(<>);
	@$top = sort { $a->{name} cmp $b->{name} } @$top;
	convert_item($top);
};

{
	local $_ = $j->encode($converted);
	s/^((?:   )+)/replace_indents($1)/emg;
	s/"\{ORDERED_KEY:\d{8}\}/"/sg;
	say $_;
}

