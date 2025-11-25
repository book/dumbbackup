use v5.24;
use Test2::V0;

# basic application
package MyApp {
    use Moo;
    with 'RYO::Command';
    use experimental 'signatures';
    sub options_spec     { }
    sub options_defaults { }
    sub call ($self) {
        Test2::V0::is( $self->arguments, ['foo'], 'MyApp arguments' );
    }
}

is( MyApp->new->command, 'my-app', 'MyApp basic command' );
MyApp->new( arguments => ['foo'] )->run;

# application with subcommands
package MyApp::WithSubs {
    use Moo;
    with 'RYO::Command', 'RYO::WithSubcommands';
    sub options_spec     { }
    sub options_defaults { }
}

package MyApp::WithSubs::Foo {
    use Moo;
    with 'RYO::Command';
    use experimental 'signatures';
    sub options_spec     { 'baz' }
    sub options_defaults { }
    sub call ($self) {
        Test2::V0::is( $self->command, 'foo', 'MyApp::Subs::Foo command' );
        Test2::V0::is(
            $self->options,
            { pager => 1, baz => 1 },
            'MyApp::Subs::Foo options'
        );
        Test2::V0::is( $self->arguments, ['bar'],
            'MyApp::Subs::Foo arguments' );

        Test2::V0::is( $self->parent->command,
            'with-subs', "MyApp::Subs::Foo parent's command" );
        Test2::V0::is(
            $self->parent->options,
            { pager => 1 },
            "MyApp::Subs::Foo parent's options"
        );
        Test2::V0::is( $self->arguments, ['bar'],
            "MyApp::Subs::Foo parent's arguments" );
    }
}

is( MyApp::WithSubs->new->command, 'with-subs', 'MyApp::Subs command' );
MyApp::WithSubs->new( arguments => [qw( foo bar --baz )] )->run;

done_testing;
