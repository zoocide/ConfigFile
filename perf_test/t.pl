use strict;
use lib '../lib';
use ConfigFile;
use FileHandle;

my $cf = ConfigFile->new('f.conf');
$cf->load;
print "$_:\n", map "  '$_'\n", sort $cf->get_arr('', $_) for sort $cf->var_names;
$cf->set_filename('r.conf');
$cf->save;

print "################\n";
my %h = read2hash('f.conf');
print "'$_' = '$h{$_}'\n" for sort keys %h;

use Benchmark qw(:all);

1 and timethese(-1, {
  config => sub{ConfigFile->new('f.conf')->load},
  read_file => sub {
    open my $f, '<', 'f.conf';
    1 while <$f>;
    close $f;
  },
  read_filehandle => sub {
    my $f = FileHandle->new('f.conf', '<');
    1 while <$f>;
  },
  read_file2array => sub {
    open my $f, '<', 'f.conf';
    my @arr;
    push @arr, $_ while <$f>;
    close $f;
  },
  read_file2hash => sub {
    my %h = read2hash('f.conf');
  },
  read_file2hash_words => sub {
    my %h = read2hash_words('f.conf');
  },
});

sub read2hash
{
  my $fname = shift;
  open my $f, '<', $fname;
  my %h;
  my $ref;
  while(<$f>) {
    if (/^\s*(\w+)\s*(\@?)=\s*(.*)/) {
      $h{$1} = $3;
      $ref = \$h{$1} if $2;
    }
    else {
      $$ref .= $_
    }
  }
  close $f;
  %h
}

sub read2hash_words
{
  my $fname = shift;
  open my $f, '<', $fname;
  my %h;
  my $ref;
  while(<$f>) {
    if (/^\s*(\w+)\s*(\@?)=\s*(.*)/) {
      $h{$1} = [split /\s+/, $3];
      $ref = $h{$1} if $2;
    }
    else {
      push @$ref, split(/\s+/, $_);
    }
  }
  close $f;
  %h
}