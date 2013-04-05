use strict;
use warnings;

use ExtUtils::testlib;
use Test::More;

    pass('*' x 10);
    BEGIN { use_ok('MR::Pack') };
    
    can_ok('MR::Pack', qw(new pack unpack depth));
    
    my $mp = MR::Pack->new;    
    isa_ok($mp, 'MR::Pack');
    
    my $test = [100500, {foo => ['bar', undef, 120, -4]}];
    my $res = $mp->unpack($mp->pack($test));
    is( $res->[1]->{foo}->[0], $test->[1]->{foo}->[0], "pack ref" );
    my @test = ('foo', ['bar', {baz => 4}]);
    my @res = $mp->unpack($mp->pack(@test));
    is( $res[1]->[2]->{baz}, $test[1]->[2]->{baz}, "pack list" );
    
    pass('*' x 10);
    print "\n";
    done_testing;
