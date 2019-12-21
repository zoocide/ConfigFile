package ConfigFile;
use strict;
use Exceptions;
use Exceptions::TextFileError;
use Exceptions::OpenFileError;
use ConfigFileScheme;

use vars qw($VERSION);
$VERSION = '0.3.0';

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

  my $inside_string = 0;
  my $multiline = 0;
  my ($ln, $s, $var, $gr, $parr, $str_beg_ln, $do_concat, $is_first);
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
        if ($s =~ s/^((?:[^\\']|\\.)++)'//) {
          # string finished
          $parr->[-1] .= $1;
          m_normalize_str($parr->[-1]);
          $inside_string = 0;
        }
        else {
          # string unfinished
          $parr->[-1] .= $s."\n";
          last;
        }
      }

      ## outside string ##
      ## skip spaces and comments ##
      $s =~ s/^(\s*)(?:#.*)?//; #< skip spaces and comments
      last if length $s == 0;
      $do_concat = !($1) && !$is_first;

      ## take next word ##
      if ($s =~ s/^((?:[^\\'# \t]|\\.)++)//) {
        # word taken
        $do_concat ? $parr->[-1].=$1
                   : push @$parr, $1;
        m_normalize_str($parr->[-1]);
      }
      elsif ($s =~ s/^'//) {
        # string encountered
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

# convert '\'' to ''' and '\\' to '\'
sub m_normalize_str
{
  $_[0] =~ s/\\([\\\$' \t])/$1/g;
  $_[0]
}

sub m_shield_str
{
  my $ret = shift;
  $ret =~ s/(\\|\')/\\$1/g;
  $ret = '\''.$ret.'\'' if $ret =~ /\s/;
  $ret
}

1;

__END__

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

=cut
