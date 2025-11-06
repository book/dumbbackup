use v5.24;
use Test::More;

# role adding the option --foo
package MyApp::OptionFoo {
    use Moo::Role;
    use experimental 'signatures';
    around options_spec => sub ( $orig, @args ) {
        return ( 'foo!', => $orig->(@args) );
    }
}

# basic application
package MyApp {
    use Moo;
    use experimental 'signatures';
    with
      'RYO::Command',
      'MyApp::OptionFoo',
      ;
    sub options_spec     { qw( bar=s ) }
    sub options_defaults { ( bar => 'baz' ) }
    sub call ( $self )   { pass('ran the app') }
}

# tests
my @tests = (
    [
        [],
        {
            pager => 1,        # default from RYO::Command
            bar   => 'baz',    # from MyApp
        },
    ],
    [
        ['--foo'],
        {
            pager => 1,        # default from RYO::Command
            foo   => 1,        # from MyApp::OptionFoo
            bar   => 'baz',    # from MyApp
        },
    ],
    [
        ['--nofoo'],
        {
            pager => 1,        # default from RYO::Command
            foo   => 0,        # from MyApp::OptionFoo
            bar   => 'baz',    # from MyApp
        },
    ],
);

for my $t (@tests) {
    my ( $args, $expected ) = @$t;
    is_deeply( MyApp->new( arguments => [@$args] )->options, $expected,
        "options for: myapp @$args" );
}

done_testing;
