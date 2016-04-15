#!/usr/bin/perl -w

#Uses the CallNumber::LC library to normalize the LCC and sort them accordingly

use strict;
no warnings "all";
use LC;

my @numbers = <>;

print "$_" for sort {
    #initialize $aa and $bb in the case Dewey #s read first
    my ($aa, $bb) = 'A';
    my ($aa, $bb) = map { Library::CallNumber::LC->normalize($_) } ($a, $b);
    $aa cmp $bb;
} @numbers;
