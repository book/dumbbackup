use v5.24;
use Test2::V0;

# role adding the option --foo
package MyApp::OptionFoo {
    use Moo::Role;
    use experimental 'signatures';
    around options_spec => sub ( $orig, @args ) {
        return ( 'foo!', => $orig->(@args) );
    }
}

# role adding the option --num
package MyApp::OptionNum {
    use Moo::Role;
    use experimental 'signatures';
    around options_spec => sub ( $orig, @args ) {
        return ( 'num=i', => $orig->(@args) );
    }
}

# basic application
package MyApp {
    use Moo;
    use experimental 'signatures';
    with 'RYO::Command';
    sub options_spec     { qw( bar=s ) }
    sub options_defaults { ( bar => 'baz' ) }
    sub call ( $self )   { pass('ran the app') }
}
package MyAppThrough {
    use Moo;
    use experimental 'signatures';
    with 'RYO::Command';
    sub options_spec     { qw( bar=s ) }
    sub options_defaults { ( bar => 'baz' ) }
    sub call ( $self )   { pass('ran the app') }
    sub getopt_config    { qw( pass_through ) }
}

# tests
my @tests = (
    [
        {
            roles => [ MyApp => 'MyApp::OptionFoo' ],
            args  => [],
        },
        {
            pager => 1,        # default from RYO::Command
            bar   => 'baz',    # from MyApp
        },
        [],
    ],
    [
        {
            roles => [ MyApp => 'MyApp::OptionFoo' ],
            args  => [ '--foo', 'zlonk' ],
        },
        {
            pager => 1,        # default from RYO::Command
            foo   => 1,        # from MyApp::OptionFoo
            bar   => 'baz',    # from MyApp
        },
        ['zlonk'],
    ],
    [
        {
            roles => [ MyApp => 'MyApp::OptionFoo' ],
            args  => [qw( --no-foo quux )],
        },
        {
            pager => 1,        # default from RYO::Command
            foo   => 0,        # from MyApp::OptionFoo
            bar   => 'baz',    # from MyApp
        },
        [qw( quux )],
    ],
    [
        {
            roles => [ MyApp => 'MyApp::OptionNum', 'MyApp::OptionFoo' ],
            args  => [ '--num', 7, '--foo' ],
        },
        {
            pager => 1,          # default from RYO::Command
            num   => 7,          # from MyApp::OptionNum
            foo   => 1,          # from MyApp::OptionFoo
            bar   => 'baz',      # from MyApp
        },
        [],
    ],
    [
        {
            roles => [ MyApp => 'MyApp::OptionNum', 'MyApp::OptionFoo' ],
            args  => [qw( -nu 9 -- --more --options and args )],
        },
        {
            pager => 1,          # default from RYO::Command
            num   => 9,          # from MyApp::OptionNum
            bar   => 'baz',      # from MyApp
        },
        [qw( --more --options and args )],
    ],
    [
        {
            roles => [ MyAppThrough => 'MyApp::OptionNum' ],
            args  => [qw( --num 3 quux -- fred )],
        },
        {
            pager => 1,        # default from RYO::Command
            num   => 3,        # from MyApp::OptionNum
            bar   => 'baz',    # from MyApp
        },
        [qw( quux -- fred )],    # pass_through
    ],
    [
        {
            roles => ['MyAppThrough'],
            args  => [qw( -- zlonk bam )],
        },
        {
            pager => 1,        # default from RYO::Command
            bar   => 'baz',    # from MyApp
        },
        [qw( -- zlonk bam )],    # pass_through
    ],
);

for my $t (@tests) {
    my ( $setup, $expected_options, $expected_arguments ) = @$t;
    my ( $base, @roles ) = $setup->{roles}->@*;
    my $class = @roles
      ? Role::Tiny->create_class_with_roles( $setup->{roles}->@* )
      : $base;
    my $app  = $class->new( arguments => [ $setup->{args}->@* ] );
    my $name = lc $base;
    is( $app->options, $expected_options,
        "options for: $name $setup->{args}->@*" );
    is( $app->arguments, $expected_arguments,
        "arguments for: $name $setup->{args}->@*" );
}

done_testing;
