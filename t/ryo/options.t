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

# tests
my @tests = (
    [
        {
            roles => ['MyApp::OptionFoo'],
            args  => [],
        },
        {
            pager => 1,        # default from RYO::Command
            bar   => 'baz',    # from MyApp
        },
    ],
    [
        {
            roles => ['MyApp::OptionFoo'],
            args  => ['--foo'],
        },
        {
            pager => 1,        # default from RYO::Command
            foo   => 1,        # from MyApp::OptionFoo
            bar   => 'baz',    # from MyApp
        },
    ],
    [
        {
            roles => ['MyApp::OptionFoo'],
            args  => ['--no-foo'],
        },
        {
            pager => 1,        # default from RYO::Command
            foo   => 0,        # from MyApp::OptionFoo
            bar   => 'baz',    # from MyApp
        },
    ],
    [
        {
            roles => ['MyApp::OptionNum'],
            args  => ['--num', 3 ],
        },
        {
            pager => 1,        # default from RYO::Command
            num   => 3,        # from MyApp::OptionNum
            bar   => 'baz',    # from MyApp
        },
    ],
    [
        {
            roles => ['MyApp::OptionNum', 'MyApp::OptionFoo'],
            args  => ['--num', 7, '--foo' ],
        },
        {
            pager => 1,        # default from RYO::Command
            num   => 7,        # from MyApp::OptionNum
            foo   => 1,        # from MyApp::OptionFoo
            bar   => 'baz',    # from MyApp
        },
    ],
);

for my $t (@tests) {
    my ( $setup, $expected ) = @$t;
    is_deeply(
        Role::Tiny->create_class_with_roles( MyApp => $setup->{roles}->@* )
          ->new( arguments => [ $setup->{args}->@* ] )->options,
        $expected,
        "options for: myapp $setup->{args}->@*"
    );
}

done_testing;
