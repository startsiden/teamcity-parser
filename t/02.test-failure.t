#!/usr/bin/env perl

use strict; use warnings;
use Test::More;

use TeamCity::Parser;

my $p = TeamCity::Parser->new();

# Lets first test the line by line based parser?

open my $f, "<", "t/data/vipr-player-failure.out" or die "cannot read test data: $!";

my @expected = (
    {
        name => 'exists',
        ok => 0,
        _class => 'Test',
        diag => "Error: Expected 'http://ws.vipr.startsiden.no/v1/videos' to be 'http://ws.vipr.satartsiden.no/v1/videos'",
    },
    {
        name => 'vipr',
        ok => 0,
        _class => 'Suite',
    },
);

while (<$f>) {
    # we read a line of TeamCity.
    my $event = $p->parse($_);
    next unless $event;
    my $exp = shift(@expected); # get next expected event
    isa_ok($event, "TeamCity::Parser::Node::" . delete $exp->{_class}, "right class for event") if exists $exp->{_class};
    foreach my $k ( keys %$exp ) {
        is($event->$k, $exp->{$k}, "$k is as expected");
    }
}

done_testing;


