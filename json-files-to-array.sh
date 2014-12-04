#!/bin/sh
pre=""
echo -n '['
while [ $# -gt 0 ]; do
	echo -n "$pre" &&
	cat "$1" &&
	pre=','
	shift
done
echo -n ']'
