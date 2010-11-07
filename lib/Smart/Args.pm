package Smart::Args;
use strict;
use warnings;
our $VERSION = '0.03';
use Exporter 'import';
use PadWalker qw/var_name/;

use Mouse::Util::TypeConstraints ();

*_get_type_constraint = \&Mouse::Util::TypeConstraints::find_or_create_isa_type_constraint;

our @EXPORT = qw/args/;

my %is_invocant = map{ $_ => undef } qw($self $class);

sub args {
    {
        package DB;
        # call of caller in DB package sets @DB::args,
        # which requires list context, but we don't need return values
        () = CORE::caller(1);
    }

    my $start = 0;

    if(@_) {
        my $name = var_name(1, \$_[0]) || '';
        if(exists $is_invocant{ $name }){ # seems method call
            $_[0] = shift @DB::args; # set the invocant
            if(defined $_[1]) { # has rule?
                $name =~ s/^\$//;
                $_[0] = _validate_by_rule({ $name => $_[0] }, $name, $_[1]);
                $start++;
            }
            $start++;
        }
    }

    my $args = ( @DB::args == 1 && ref($DB::args[0]) )
            ?    $DB::args[0]  # must be hash
            : +{ @DB::args };  # must be key-value list

    ### $args
    ### @_

    # args my $var => RULE
    #         ~~~~    ~~~~
    #         undef   defined

    for(my $i = $start; $i < @_; $i++){

        (my $name = var_name(1, \$_[$i]))
            or  Carp::croak('usage: args my $var => TYPE, ...');

        $name =~ s/^\$//;

        # with rule  (my $foo => $rule, ...)
        if(defined $_[ $i + 1 ]) {
            $_[$i] = _validate_by_rule($args, $name, $_[$i + 1]);
            $i++;
        }
        # without rule (my $foo, my $bar, ...)
        else {
            if(!exists $args->{$name}) { # parameters are mandatory by default
                Carp::croak("missing mandatory parameter named '\$$name'");
            }
            $_[$i] = $args->{$name};
        }
    }
}

sub _validate_by_rule {
    my($args, $name, $basic_rule) = @_;

    # compile the rule
    my %rule;
    if(ref($basic_rule) eq 'HASH') {
        # rule: { isa => $type, optiona => $bool, default => $default }
        %rule = %{$basic_rule};
        if ($basic_rule->{isa}) {
            $rule{type} = _get_type_constraint($basic_rule->{isa});
        }
    }
    else {
        # $rule is a type constraint name or type constraint object
        $rule{type} = _get_type_constraint($basic_rule);
    }

    my $value = $args->{$name};

    # validate the value by the rule
    if(exists $args->{$name}){
        if(my $tc = $rule{type} ){
            if(!$tc->check($value)){
                $value = _try_coercion_or_die($tc, $value);
            }
        }
    }
    else{
        if(exists $rule{default}){
            $value = $rule{default};
        }
        elsif(!$rule{optional}){
            Carp::croak("missing mandatory parameter named '\$$name'");
        }
        else{
            # noop
        }
    }
    return $value;
}

sub _try_coercion_or_die {
    my($tc, $value) = @_;
    if($tc->has_coercion) {
        $value = $tc->coerce($value);
        $tc->check($value) and return $value;
    }
    Carp::croak($tc->get_message($value));
}
1;
__END__

=head1 NAME

Smart::Args - argument validation for you

=head1 SYNOPSIS

  use Smart::Args;

  sub func2 {
    args my $p => 'Int',
         my $q => { isa => 'Int', optional => 1 };
  }
  func2(p => 3, q => 4); # p => 3, q => 4
  func2(p => 3);         # p => 3, q => undef

  sub func3 {
    args my $p => {isa => 'Int', default => 3},
  }
  func3(p => 4); # p => 4
  func3();       # p => 4

  package F;
  use Moose;
  use Smart::Args;

  sub method {
    args my $self,
         my $p => 'Int';
  }
  sub class_method {
    args my $class,
         my $p => 'Int';
  }

  my $f = F->new();
  $f->method(p => 3);

  F->class_method(p => 3);

=head1 DESCRIPTION

Smart::Args is yet another argument validation library.

This module makes your module more readable, and writable =)

=head1 FUNCTIONS

=head2 C<args my $var [, $rule], ...>

Checks arguments and fills them into lexical variables.

The arguments consist of a lexical <$var> and an optional I<$rule>.

I<$rule> can be a type name (e.g. C<Int>), a HASH reference (with 
C<type>, C<default>, and C<optional>), or a type constraint object.

See the SYNOPSIS section.

=head1 TYPES

The types that C<Smart::Args> uses are type constraints of C<Mouse>.
That is, you can define your types in the way Mouse does.

In addition, C<Smart::Args> also allows Moose type constraint objects,
so you can use any C<MooseX::Types::*> libraries on CPAN.

Type coercions are automatically tried if validations fail.

See L<Mouse::Util::TypeConstraints> for details.

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom  slkjfd gmail.comE<gt>

=head1 SEE ALSO

L<Params::Validate>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut