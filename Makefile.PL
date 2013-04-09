use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'MR::Pack',
    VERSION_FROM      => 'lib/MR/Pack.pm',
    PREREQ_PM         => {},
    LIBS              => [''],
    DEFINE            => '',
    INC               => '-I.',
    OPTIMIZE        => $ENV{'OPTIMIZE'}    
);
