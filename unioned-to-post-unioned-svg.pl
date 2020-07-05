#!/usr/bin/perl

use warnings;
use strict;
use 5.010;
use Carp;

use XML::LibXML;
use Image::SVG::Path qw/extract_path_info create_path_string/;

my $minimum_segment_length = 0.008;

###

sub process_all_paths {
	my $in_fh = shift // \*STDIN;
	my $out_fh = shift // \*STDOUT;
	
	my $parser = XML::LibXML->new();
	my $doc = $parser->parse_fh($in_fh);

	my $xpc = XML::LibXML::XPathContext->new($doc);
	$xpc->registerNs('svg', 'http://www.w3.org/2000/svg');

	my @paths = $xpc->findnodes('/svg:svg//svg:path[@d]');

	foreach my $path (@paths) {
		my $old_commands = $path->getAttribute('d');
		my $new_commands = process_path_data($old_commands);
		$path->setAttribute('d', $new_commands);
	}

	$doc->toFH($out_fh);
}

sub get_segment_length {
	my $segment = shift;
	my $dx = $segment->{x1} - $segment->{x0};
	my $dy = $segment->{y1} - $segment->{y0};
	return sqrt(($dx * $dx) + ($dy * $dy));
}

sub get_segment {
	my $previous_segment = shift;
	my $element = shift;

	if($element->{position} ne 'absolute') {
		croak "Expected absolute position";
	}

	my $s0 = $previous_segment // {
		x0 => 0,
		y0 => 0,
		x1 => 0,
		y1 => 0,
		name => 'closepath',
	};

	my $s1 = {
		x0 => $s0->{x1},
		y0 => $s0->{y1},
		name => $element->{name},
		element => $element,
	};

	if($element->{name} eq 'closepath') {
		if($s0->{name} eq 'closepath') {
			croak "closepath not expected before the beginning of a subpath";
		}
		delete $s1->{x0};
		delete $s1->{y0};
		$s1->{x1} = $s0->{x1};
		$s1->{y1} = $s0->{y1};
	}
	elsif($element->{name} eq 'moveto') {
		if($s0->{name} ne 'closepath') {
			croak "moveto not expected after the beginning of a subpath";
		}
		$s1->{x1} = $element->{point}[0];
		$s1->{y1} = $element->{point}[1];
	}
	elsif($element->{name} =~ /^(lineto|curveto)$/) {
		if($s0->{name} eq 'closepath') {
			croak "$element->{name} not expected before the beginning of a subpath";
		}
		$s1->{x1} = $element->{end}[0];
		$s1->{y1} = $element->{end}[1];
	}
	else {
		croak "I don't know how to handle $element->{name}";
	}


	return $s1;
}


sub process_path_data {
	my $d = shift;
	my @path_elements = extract_path_info($d, { absolute => 1 });

	my @segments;

	my $s0 = undef;
	foreach(@path_elements) {
		my $s1 = get_segment($s0, $_);
		my $length;

		if(defined $s1->{x0}) {
			$length = get_segment_length($s1);
		}

		if(defined $length and $length < $minimum_segment_length) {
			say STDERR "$0: Skipping $s1->{name} segment with length of $length < $minimum_segment_length";
		}
		else {
			push @segments, $s1;
		}

		$s0 = $s1;
	}

	my @filtered_path_elements = map { $_->{element} } @segments;

	return create_path_string(\@filtered_path_elements);
}

###

say STDERR "$0: Post-processing path data";
process_all_paths();
say STDERR "$0: Post-processing completed normally";
