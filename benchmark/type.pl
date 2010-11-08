#!perl -w
use strict;
use Benchmark qw(:all);

use Params::Validate qw(:all);
use Smart::Args;

foreach my $mod (qw(Params::Validate Smart::Args)) {
    print $mod, "/", $mod->VERSION, "\n";
}

sub pv_add {
    my %args = validate( @_ =>
        {
            x => { type => SCALAR },
            y => { type => SCALAR },
        });
    return $args{x} + $args{y};
}

sub sa_add {
    args my $x => 'Value', my $y => 'Value';
    return $x + $y;
}

sub sa_isa_add {
    args my $x => { isa => 'Value' }, my $y => { isa => 'Value' };
    return $x + $y;
}

print "with type constraints: SCALAR / Value\n";
cmpthese -1, {
    'P::Validate' => sub {
        my $x = pv_add({ x => 10, y => 10 });
    },
    'S::Args' => sub {
        my $x = sa_add({ x => 10, y => 10 });
    },
    'S::Args/isa' => sub {
        my $x = sa_isa_add({ x => 10, y => 10 });
    },
};
