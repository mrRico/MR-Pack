use strict;
use warnings;

use ExtUtils::testlib;
use Test::More;

    pass('*' x 10);
    BEGIN { use_ok('MR::Pack') };
    
    can_ok('MR::Pack', qw(new pack unpack depth utf8_on));
    
    my $mp = MR::Pack->new;    
    isa_ok($mp, 'MR::Pack');
    
    my $test = [100500, {foo => ['bar', undef, 120, -4]}];
    my $res = $mp->unpack($mp->pack($test));
    is( $res->[1]->{foo}->[0], $test->[1]->{foo}->[0], "pack ref" );
    my @test = ('foo', ['bar', {baz => 4}]);
    my @res = $mp->unpack($mp->pack(@test));
    is( $res[1]->[2]->{baz}, $test[1]->[2]->{baz}, "pack list" );
    my $utf = 'привет';
    is( $mp->unpack($mp->pack($utf)), $utf, "utf without flag" );
    is( $mp->utf8_on(1)->unpack($mp->pack($utf)), "\x{043F}\x{0440}\x{0438}\x{0432}\x{0435}\x{0442}", "utf with flag" );
    my $int = -(2**31 - 1);
    is( $mp->unpack($mp->pack($int)), $mp->unpack($mp->pack("$int")), "signed int as string" );
    $int = 2**32-1;
    is( $mp->unpack($mp->pack($int)), $mp->unpack($mp->pack("$int")), "unsigned int as string" );
    
    pass('*' x 10);
    print "\n";
    done_testing;
