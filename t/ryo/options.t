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
is_deeply(
    MyApp->new( arguments => [] )->options,
    {
        pager => 1,        # default from RYO::Command
        bar   => 'baz',    # from MyApp
    },
    'options for: myapp'
);
is_deeply(
    MyApp->new( arguments => ['--foo'] )->options,
    {
        pager => 1,        # default from RYO::Command
        foo   => 1,        # from MyApp::OptionFoo
        bar   => 'baz',    # from MyApp
    },
    'options for: myapp --foo'
);
is_deeply(
    MyApp->new( arguments => ['--no-foo'] )->options,
    {
        pager => 1,        # default from RYO::Command
        foo   => 0,        # from MyApp::OptionFoo
        bar   => 'baz',    # from MyApp
    },
    'options for: myapp --foo'
);

done_testing;
