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

sub utf8 {
    my $self = shift;
    @_ ? $self->set_utf8($_[0]) : $self->get_utf8(); 
}

1;
__END__
