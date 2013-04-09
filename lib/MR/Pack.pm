package MR::Pack;
use strict;
use warnings;

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('MR::Pack', $VERSION);

sub depth {
    my $self = shift;
    @_ ? $self->set_depth($_[0]) : $self->get_depth(); 
}

sub utf8_on {
    my $self = shift;
    @_ ? $self->set_utf8_on($_[0]) : $self->get_utf8_on(); 
}

1;
__END__
=encoding utf-8

=head1 NAME

MR::Pack - like messagepack but different binary encoded representation 

=head1 SYNOPSIS

    use MR::Pack;
    
    my $mp = MR::Pack->new;
    
    my @data = ('foo', ['bar'], {'baz' => 100500});
    my $packed_data = $mp->pack(@data);
    my @unpack_data = $mp->unpack($packed_data); 
    
    my $data = (['bar']);
    my $packed_data = $mp->pack($data);
    my $unpack_data = $mp->unpack($packed_data);
    
    # UTF-8
    my $data = (['привет']); # or (["\x{043F}\x{0440}\x{0438}\x{0432}\x{0435}\x{0442}"]) 
    my $packed_data = $mp->pack($data);
    my $unpack_data = $mp->unpack($packed_data); # eq 'привет' 
    $unpack_data = $mp->utf8_on(1)->unpack($packed_data); # eq "\x{043F}\x{0440}\x{0438}\x{0432}\x{0435}\x{0442}"
    
=head1 DESCRIPTION

MR::Pack use custom binary encoded representation, where first byte stores variable type and integer base 16 digits. 
All another bytes are compressed unsigned integer stores base 128 digits like a classic BER (see perlpacktut). 

=head1 METHODS

=head2 new

create a new instance of C<MR::Pack>.

=head2 utf8_on(bool)

Set C<UTF8> flag on string value. This one sensitive only for C<unpack>. When invoke with argument, then it return instance.
Default: 0

=head2 depth(int)

Max order to detect circular references. When invoke with argument, then it return instance.
Default: 512

=head1 NOTE

- It doesn't works with any tie or blessed values.

- There is no stream mode.

- Yes, it works with simple list (array) of smth.

- In some case it has better packing behaviour than L<Data::MessagePack>.

- Yes, L<Data::MessagePack> is great.

=head1 SPEED

Speed is the same or comparable L<Data::MessagePack>

=head1 THANKS TO

L<Data::MessagePack>

=head1 LICENSE

This library is under meow license.

=cut
