use ExtUtils::MakeMaker;

#my @parts = qw/ascii_pack/;
#my $cfiles = [ map { "$_.c" } @parts ];
#my $ofiles = join ' ', map { "$_.o" } @parts;

WriteMakefile(
    NAME              => 'MR::Pack',
    VERSION_FROM      => 'lib/MR/Pack.pm',
    PREREQ_PM         => {},
    LIBS              => [''],
    DEFINE            => '',
    INC               => '-I.',
    
#    C                 => $cfiles,
#    OBJECT            => "Pack.o $ofiles",
    #OPTIMIZE        => $ENV{'OPTIMIZE'}    
);
