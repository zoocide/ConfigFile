package ConfigFile;
use strict;
use Exceptions;
use Exceptions::TextFileError;
use Exceptions::OpenFileError;
use ConfigFileScheme;

use vars qw($VERSION);
$VERSION = '0.4.0';

# TODO: CONFIGURATION FILE: make variable multiline by 'var @= value'
# TODO: substitute special symbols \n, \t
# TODO: shield line feeding by placing \ at the end of line.
# TODO: allow change comment symbol to ;
# TODO: allow preset variables for file parsing.


=head1 NAME

ConfigFile - read and write configuration files aka '.ini'.

=head1 SYNOPSIS

  ## load configuration file ##
  my $decl = ConfigFileScheme->new( multiline => 1,... );
  my $cf   = ConfigFile->new($file_name, $decl);
  # <=>
  my $cf = ConfigFile->new($file_name, { multiline => 1,... });
  # <=>
  my $cf = ConfigFile->new($file_name,   multiline => 1,...  );
  # or
  my $cf = ConfigFile->new($file_name);

  # Ignoring unrecognized lines is useful when you want to read some scalar
  # varibles, but there can be multiline variables and you are not interested
  # in these values.
  $cf->skip_unrecognized_lines(1);

  try{
    $cf->load; #< all checks are included
  }
  catch{
    print map "warning: $_\n", @{$@};
  } 'List';
  # <=>
  print "warning: $_\n" for $cf->load; #< It raises exception if can not open file.

  ## access variables ##
  my $str = $cf->get_var('group', 'var', 'default value');
  my @array = $cf->get_arr('group', 'var', @default_value);

  my $value;
  $value = $cf->get_var('group', 'var', 'default value');
  # <=>
  $value = $cf->is_set('group', 'var') ? $cf->get_var('group', 'var')
                                       : 'default value';

  ## save configuration file ##
  my $cf = ConfigFile->new($file_name);
  $cf->set_group('group');
  $cf->set_var('var_name', @values);
  $cf->save;

  --------
  $cf->check_required;         ##< according to declaration
  $cf->check_required($hash);  ##< according to $hash, defining required variables
  $cf->check_required('gr' => [@vars],...); ##< hash constructor

=cut


# throws: -
sub new
{
  my $self = bless {}, shift;
  $self->init(@_);
  $self
}

sub init
{
  my $self  = shift;
  my $fname = shift;
  my $decl  = !@_                  ? ConfigFileScheme->new
            : !ref $_[0]           ? ConfigFileScheme->new(@_)
            :  ref $_[0] eq 'HASH' ? ConfigFileScheme->new(%{$_[0]})
                                   : $_[0];
  $self->{fname}     = $fname;
  $self->{content}   = {};
  $self->{cur_group} = '';
  $self->{decl}      = $decl;
  $self->{skip_unrecognized_lines} = 0;
}


## config file rules ##
# error: [complex group]
# ok   : [group]
# error: var name with spaces = value
# ok   : var_1 = a complex value
# ok   :   # comment string
# ok   : var_2 = '  a complex value  '
# error: var_3 = 'a complex value
# ok   : var_4 = 'a complex value' tail
# ok   : var_5 = 'a complex
# ok   :      # this is a part of the string
# ok   :
# ok   :  new lines are saved in this string
# ok   :   value'
# ok   : var_6 = head \'complex value\'
# ok   : var_7 = \\n is not a new line
# ok   : # set empty value
# ok   : var_8 =
# error:   value
# ok   : arr_1 = elm1
# ok   : arr_2 = elm1 elm2 'complex element'
# ok   : elm3
# ok   :   elm4 elm5
# ok   : arr_3 =
# ok   : elm1 elm2 elm3 elm4
# ok   : a1=a b 'c d' \'e '\\# 'f g

# throws: Exceptions::OpenFileError, [Exceptions::TextFileError]
sub load
{
  my $self = shift;
  my $decl = $self->{decl};
  my @errors;

  open(my $f, '<', $self->{fname}) || throw OpenFileError => $self->{fname};

  $self->{interpolate} = 1;
  my $inside_string = 0;
  my $multiline = 0;
  my ($ln, $s, $var, $gr, $parr, $str_beg_ln, $do_concat, $is_first, $q);
  for ($ln = 0; $s = <$f>; $ln++) {
    #print $s;
    chomp $s;
    if (!$inside_string) {
      ## determine expression type ##
      if ($s =~ /^\s*(#|$)/){
        # comment string
        next;
      }
      elsif ($s =~ /^\s*\[(\w+)\]\s*$/) {
        # group declaration
        $self->set_group($gr = $1);
        $multiline = 0;
        next;
      }
      elsif ($s =~ s/^\s*(\w+)\s*=//) {
        # assignment statement
        $var = $1;
        if (!$decl->is_valid($gr, $var)) {
          push @errors, Exceptions::TextFileError->new($self->{fname}, $ln, "invalid variable '$var'");
          $multiline = 0;
          next;
        }
        $multiline = $decl->is_multiline($gr, $var);
        $self->{content}{$gr}{$var} = ($parr = []);
      }
      elsif (!$multiline) {
        # unrecognized string
        $self->{skip_unrecognized_lines} ||
            push @errors, Exceptions::TextFileError->new($self->{fname}
                        , $ln, "unrecognized line '$s'");
        next;
      }
    }

    ## read value ##
    $is_first = 1; #< do not concatenate the first
    while (length $s > 0 || $inside_string) {
      if ($inside_string) {
        if ($s =~ s/^((?:[^\\$q]|\\.)*+)$q//) {
          # string finished
          $parr->[-1] .= $self->m_interpolate_str($1);
          $inside_string = 0;
          $self->{interpolate} = 1;
        }
        else {
          # string unfinished
          $parr->[-1] .= $self->m_interpolate_str($s)."\n";
          last;
        }
      }

      ## outside string ##
      ## skip spaces and comments ##
      $s =~ s/^(\s*)(?:#.*)?//; #< skip spaces and comments
      last if length $s == 0;
      $do_concat = !($1) && !$is_first;

      ## take next word ##
      if ($s =~ s/^((?:[^\\'"# \t]|\\.)++)//) {
        # word taken
        if ($do_concat) {
          $parr->[-1] .= $self->m_interpolate_str($1);
        }
        elsif ($1 =~ /^\$({(?:(\w*)::)?)?(\w++)(?(1)})(?=\s|#|$)/) {
          # array interpolation
          push @$parr, $self->get_arr(defined $2 ? $2||'' : $self->{cur_group}, $3);
        }
        else {
          push @$parr, $self->m_interpolate_str($1);
        }
      }
      elsif ($s =~ s/^(['"])//) {
        # string encountered
        $q = $1;
        $self->{interpolate} = $q eq '"';
        $inside_string = 1;
        $str_beg_ln = $ln;
        $do_concat or push @$parr, '';
      }
      else {
        push @errors, Exceptions::TextFileError->new($self->{fname}
                        , $ln, "unexpected string '$s' encountered");
      }
      $is_first = 0;
    }
  }

  if ($inside_string){
    push @errors, Exceptions::TextFileError->new($self->{fname}, $ln-1, "unclosed string (see from line $str_beg_ln)");
  }
  close $f;

  try{
    $self->check_required;
  }
  catch{
    push @errors, @{$@};
  } 'List';

  if (@errors){
    return @errors if wantarray;
    throw List => @errors;
  }
}

sub load2
{
  my $self = shift;
  my $decl = $self->{decl};
  my @errors;

  open(my $f, '<', $self->{fname}) || throw OpenFileError => $self->{fname};

  $self->{interpolate} = 1;
  my $inside_string = 0;
  my $multiline = 0;
  my $gr = '';
  my $do_concat = 0;
  my ($ln, $s, $var, $parr, $str_beg_ln, $is_first, $q);
  my $add_word = sub { $do_concat ? $parr->[-1] .= $_[0] : push @$parr, $_[0]; $do_concat = 1 };
  my $space = qr~(?:\s++|#.*|\r?\n)\r?\n?(?{ $do_concat = 0 })~s;
  my $normal_word = qr~((?:[^\\\'"# \t\n]|\\.)++)(?{ &$add_word($self->m_interpolate_str($^N)) })~;
  my $q_str_beg  = qr~'((?:[^\\']|\\.)*+)(?{ $self->{interpolate} = 0; &$add_word($self->m_interpolate_str($^N)) })~s;
  my $qq_str_beg = qr~"((?:[^\\"]|\\.)*+)(?{ &$add_word($self->m_interpolate_str($^N)) })~s;
  my $q_str_end  = qr~((?:[^\\']|\\.)*+)'(?{ $parr->[-1].=$self->m_interpolate_str($^N); $self->{interpolate}=1;})~s;
  my $qq_str_end = qr~((?:[^\\"]|\\.)*+)"(?{ $parr->[-1].=$self->m_interpolate_str($^N)})~s;
  my $q_str = qr<$q_str_beg$q_str_end>;
  my $qq_str = qr<$qq_str_beg$qq_str_end>;
  my ($vg, $vn);
  my $as_vn = qr<(\w++)(?{$vn = $^N})>;
  my $as_vg = qr<(?:(\w*)::(?{$vg = $^N})|(?{$vg = $gr}))>;
  my $array_substitution = qr~(?(?{$do_concat})(?!))\$(?:{$as_vg$as_vn}|$as_vn)$space(?{
    push @$parr, $self->get_arr($vg, $vn);
  })~;
  my $value_part = qr<^(?:$array_substitution|$space|$normal_word|$q_str_beg(?:$(?{
    $q = '\'';
    $str_beg_ln = $ln;
    $inside_string = 1;
  })|$q_str_end)|$qq_str_beg(?:$(?{
    $q = '"';
    $str_beg_ln = $ln;
    $inside_string = 1;
  })|$qq_str_end))*+$>;
  my $var_decl_beg = qr~^\s*(\w+)\s*=(?{
    $var = $1;
    $self->{content}{$gr}{$var}= $parr = [];
    $multiline = $decl->is_multiline($gr, $var);
  })~;
  for ($ln = 0; $s = <$f>; $ln++) {
    if (!$inside_string) {
      # skip comment and blank string
      next if $s =~ /^\s*(#|$)/;
      # process group declaration
      next if $s =~ /^\s*\[(\w+)\]\s*$(?{$self->set_group($gr = $1); $multiline = 0})/;
      # process variable declaration
      if ($s =~ s/$var_decl_beg// || $multiline) {
        if ($s !~ /$value_part/) {
          push @errors, Exceptions::TextFileError->new($self->{fname}
                      , $ln, "unexpected string '$s' encountered");
        }
      }
      else {
        # unrecognized string
        $self->{skip_unrecognized_lines} ||
            push @errors, Exceptions::TextFileError->new($self->{fname}
                        , $ln, "unrecognized line '$s'");
        next;
      }
    }
    else {
      # read string
      if (!($q eq '\'' && $s =~ s/$q_str_end// || $q eq '"' && $s =~ s/$qq_str_end//)) {
        # string is not finished
        $parr->[-1] .= $self->m_interpolate_str($s);
        next;
      }
      $inside_string = 0;
      if ($s !~ /$value_part/) {
        push @errors, Exceptions::TextFileError->new($self->{fname}
                    , $ln, "unexpected string '$s' encountered");
      }
    }
  }

  if ($inside_string){
    push @errors, Exceptions::TextFileError->new($self->{fname}, $ln-1, "unclosed string (see from line $str_beg_ln)");
  }
  close $f;

  try{
    $self->check_required;
  }
  catch{
    push @errors, @{$@};
  } 'List';

  if (@errors){
    return @errors if wantarray;
    throw List => @errors;
  }
}

# throws: Exceptions::List
sub check_required
{
  my $self = shift;
  my $decl = @_ ? ConfigFileScheme->new(required => (ref $_[0] ? $_[0] : {@_}))
                : $self->{decl};
  $decl->check_required($self->{content});
}

# throws: string, Exceptions::OpenFileError
sub save
{
  my $self = shift;
  open(my $f, '>', $self->{fname}) || throw OpenFileError => $self->{fname};
  for my $gr_name (sort keys %{$self->{content}}){
    my $gr = $self->{content}{$gr_name};
    print $f "\n[$gr_name]\n" if $gr_name;
    for (sort keys %$gr){
      my $prefix = $self->{decl}->is_multiline($gr, $_) ? "\n  " : ' ';
      print $f "$_ =", (map $prefix.m_shield_str($_), @{$gr->{$_}}), "\n";
    }
  }
  close $f;
}

sub file_name { $_[0]{fname} }
sub get_var   { defined $_[0]{content}{$_[1]}{$_[2]} ? "@{$_[0]{content}{$_[1]}{$_[2]}}" : $_[3] }
sub get_arr   { defined $_[0]{content}{$_[1]}{$_[2]} ? @{$_[0]{content}{$_[1]}{$_[2]}} : @_[3..$#_] }
sub is_set    { defined $_[0]{content}{$_[1]}{$_[2]} }

sub set_group { $_[0]{cur_group} = $#_ < 1 ? '' : $_[1] }
sub set_var   { $_[0]{content}{$_[0]{cur_group}}{$_[1]} = [@_[2..$#_]] }
sub set_var_if_not_exists
{
  $_[0]{content}{$_[0]{cur_group}}{$_[1]} = [@_[2..$#_]] if !exists $_[0]{content}{$_[0]{cur_group}}{$_[1]}
}
sub skip_unrecognized_lines
{
  my $self = shift;
  my $ret = $self->{skip_unrecognized_lines};
  $self->{skip_unrecognized_lines} = $_[0] ? 1 : 0 if @_;
  $ret
}
sub erase { $_[0]{content} = {}; $_[0]{cur_group} = ''; }

# $self->m_interpolate_str($str);
sub m_interpolate_str
{
  my $self = shift;
  my $str = shift;
  if ($self->{interpolate}) {
    $str =~ s/
      # normalize string
      \\([\\\$'#" \t])
      |
      # interpolate variables
      \$({(?:(\w*)::)?)?(\w++)(?(2)})
    /$1 || $self->get_var(defined $3 ? $3||'' : $self->{cur_group}, $4, '')/gex;
  }
  else {
    # just normalize
    $str =~ s/\\([\\\$'" \t])/$1/g;
  }
  $str
}

sub m_shield_str
{
  my $ret = shift;
  if ($ret =~ /\s|\n/) {
    $ret =~ s/([\\'])/\\$1/g;
    $ret = '\''.$ret.'\'';
  }
  else {
    $ret =~ s/([\\'"\$#])/\\$1/g;
  }
  $ret
}

1;

__END__

=head1 CONFIGURATION FILE

File consist of groups and variables definition lines.
One file line for one definition.
Also, there can be blank lines and comment lines.
Comments begins with # and ends with the line.

=head2 Group

C<[group_name]>

I<group_name> is one word matching B<\w+> pattern.
Group definition splits the file on sections.
Each group has its own variables set.
Different groups can have variables with the same name, but it still different
variables.

=head2 Variable

C<var_name = value>

I<var_name> is one word matching B<\w+> pattern.
Value part of the string begins just after the assignment symbol and ends with
the line.
Value is a space separated list of words.
There is special words such as string literal and variable substitution.
Variable declaration parsed into a list of words, which can be accessed by the
L</get_arr> and L</get_var> methods.
By default, variable declaration ends with the line (except string literal,
which can have line feeding inside), but there is special case when parser
treats all next lines as the value part continuation until the next declaration
occurred.
This behaviour is enabled by telling the parser that variable is B<multiline>.

=head3 Variables substitution

C<$var> or C<${var}> or C<${group::var}>

Once encountered such a construct it is replaced with the string value of the
corresponding variable existing at that moment.
In the first and second forms the group treated as the current group.
If the whole word is the one variable substitution, this word will be replaced
by the list value of the variable.

=head3 String literal "", ''

String literal begins with the qoute ' or " and ends with the corresponding
quote.
String literal is treated as one word.
All spaces in quoted string are preserved.
Symbol # inside the quoted string has no special meaning.
Like in Perl inside a '' string parser will not interpolate variables and
symbol \ will have special meaning only just before another \ or '.
In double qouted string "" variables interpolation is enabled and symbol \ will
shield any next symbol or have special meaning, like "\n".

=head1 METHODS

=over

=item new($filename, declaration)

  my $decl = ConfigFileScheme->new( multiline => 1,... );
  my $cf   = ConfigFile->new($file_name, $decl);
  # the same as #
  my $cf = ConfigFile->new($file_name, { multiline => 1,... });
  # the same as #
  my $cf = ConfigFile->new($file_name,   multiline => 1,...  );
  # or #
  my $cf = ConfigFile->new($file_name);

=item load

Read and parse the file. All occurred discrepancies will be thrown as exceptions.

=item check_required

=item check_required($hash)

=item check_required(@hash)

=item get_var('group', 'variable', 'default value')

Get group::variable value as a string.
If the variable is not set, method returns 'default value'.

=item get_arr('group', 'variable', @default_value)

Get group::variable value as an array.
If the variable is not set, method returns the array @default_value.

=item set_group('group')

Set current group to the specified name.

=item set_var('variable', @value)

Assign @value to the variable from the current group.

=item save

Write configuration into file.

=back

=head1 AUTHOR

Alexander Smirnov <zoocide@gmail.com>

=head1 LICENSE

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
