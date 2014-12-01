use strict;
use warnings;
package TeamCity::Parser;
use Moo;
use Types::Standard qw(Object); 
use Carp qw();

# XXX: this is ugly right?
has 'current_suite' => ( is => 'rw', isa => Object, clearer => 'end_suite' );
has 'current_test' => ( is => 'rw', isa => Object, clearer => 'end_test' );

=method parse( $line )

Will parse line, and if it was the end of a suite or a test, we return that

Note that this usually means you will get the tests of a suite before you get the
suite.

=cut

sub parse {
    my ( $self, $line ) = @_;

    return TeamCity::Parser::End->new() unless defined $line;
    if ($line =~ m/^##teamcity\[testSuiteStarted name='(.*?)'/) {
        Carp::croak sprintf("Already in a suite? %s is new name, current suite is %s",
            $1, $self->current_suite->name
        ) if $self->current_suite;
        $self->current_suite(TeamCity::Parser::Node::Suite->new(name => $1));
        return;
    }
    if ($line =~ m/^##teamcity\[testSuiteFinished name='(.*?)'/) {
        my $suite = $self->current_suite;
        Carp::croak "No current suite, but got suiteFinished? name: $1" unless $suite;
        Carp::croak sprintf("Wrong suite end name, got %s, expected %s", $1, $suite->name)
        unless $1 eq $suite->name;
        $self->end_suite;
        return $suite;
    }
    if ($line =~ m/^##teamcity\[testStarted name='(.*?)' (.*?)\]$/) {
        # start a test, not sure what will be in $2
        Carp::croak "No active suite? got test named $1" unless $self->current_suite;
        $self->current_test(TeamCity::Parser::Node::Test->new(
                name => $1,
                suite => $self->current_suite
            )
        );
        $self->current_suite->add_test( $self->current_test );
        return;
    }
    if ($line =~ m/^##teamcity\[testFinished name='(.*?)'/) {
        Carp::croak "No active test? Got end of test named $1" unless $self->current_test;
        my $test = $self->current_test;
        $self->end_test;
        return $test;
    }
    # XXX: this needs refinement I think, it feels hackish. Read up on
    # http://confluence.jetbrains.com/display/TCD3/Build+Script+Interaction+with+TeamCity
    # for escapes etc in TeamCity messages
    if ($line =~ m/^##teamcity\[testFailed.*details='(.*?).\|n\s+at/) {
        Carp::croak "No active test? Got test failed, with details $1" unless $self->current_test;
        my $details = $1;
        # need to cleanup details, change escapes etc?
        $details =~ s/\|n/\n/g;
        $details =~ s/\|'/'/g;
        $self->current_test->fail($details);

        my $test = $self->current_test;
        return;
    }
}

package TeamCity::Parser::Node;

use Moo::Role;
use Types::Standard qw( Str Bool);

has name => (is => 'ro', isa => Str, required => 1);
has ok => (is => 'rw', isa => Bool, default => 1);


package TeamCity::Parser::Node::Suite;

use Moo;
use Types::Standard qw( ArrayRef );
with 'TeamCity::Parser::Node';

has tests => (is => 'ro', isa => ArrayRef, default => sub { [] });

sub add_test {
    my ($self, $test) = @_;

    push @{ $self->tests }, $test;
}

package TeamCity::Parser::Node::Test;
use Moo;
use Types::Standard qw( Str Object );
with 'TeamCity::Parser::Node';

has diag => ( is => 'rw', isa => Str, required => 0 );
has suite => ( is => 'ro', isa => Object, required => 1, weak_ref => 1);

sub fail {
    my ( $self, $diag ) = @_;
    $self->diag($diag);
    $self->ok(0);
    $self->suite->ok(0);
}

package TeamCity::Parser::End;

use Moo;

1;

1;
