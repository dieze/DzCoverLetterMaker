#/usr/bin/perl -w

use strict;
use sigtrap;
use warnings;

use feature 'say';
use Cwd qw(realpath);
use File::Basename;
use Config::Abstract::Ini;

my $dirname = dirname(realpath($0));

##### Configuration #####

# letters destination directory
my $letters_dir = "$dirname/letters";

=pod
parse a ini file $ini and return a %hash of each [SECTION] -> (Elements...)
=cut
sub parse_ini {
  my $ini = shift @_
  || die("parse_ini: one scalar parameter expected, none passed");

  $ini = new Config::Abstract::Ini("$dirname/enterprises.ini");
  my %ini = $ini->get_all_settings;
  return %ini;
}

=pod
read a file $file and return a scalar of its content
=cut
sub scalar_file {
  my $file = shift @_ || die("scalar_file: one scalar parameter expected, none passed");

  open FILE, "<$file" || die("scalar_file: can't open $file in read mode");

  my $scalar;
  while(<FILE>) { $scalar .= $_; }

  close FILE;
  return $scalar;
}

my %ini;

my $sender;

my $id;
my $hash;

my $begindate;
my $enddate;
my $period;

my $name;
my $address;
my $postal;
my $city;
my $tutor;
my $rank;
my $job;
my $phone;
my $mail;
my $web;

my $recipient;
my $rankclose;

my $letter;
my $letter_skeleton;

my $makefile_l;
my $makefile_g;

chdir "$letters_dir" or die("chdir: Can't open directory $letters_dir");
%ini = parse_ini("$dirname/enterprises.ini");
$letter_skeleton = scalar_file("$dirname/skeleton.tex");

$makefile_g .= "MAKECMD = make && make clean\n";
$makefile_g .= "MAKECMD_GEN = make gen && make clean\n";
$makefile_g .= "\nall:";
while(($id,$hash) = each(%ini)) {
  $makefile_g .= " \\\n\t$id";
}
$makefile_g .= "\ngen:";
while(($id,$hash) = each(%ini)) {
  $makefile_g .= " \\\n\t$id.gen";
}
$makefile_g .= "\n";
$makefile_g .= "\nclean:\n\t\@rm -f */*.{log,aux,div,toc,lot,lof,tns,synctex.gz}\n";

# retieve sender file content
$sender = scalar_file("$dirname/sender.tex");

# retrieving important informations
$hash = $ini{'main'};
$begindate = $$hash{'begindate'} or die("No begin date");
$enddate = $$hash{'enddate'} or die("No end date");
$period = $$hash{'period'} or die("No Period");

# Repeat for each ini entry
while(($id,$hash) = each(%ini)) {
  next if $id eq 'main';

  $name    = ($$hash{'name'} or "");
  $tutor   = ($$hash{'tutor'} or "");
  $rank    = ($$hash{'rank'} or "");
  $job     = ($$hash{'job'} or "");
  $address = ($$hash{'address'} or "");
  $postal  = ($$hash{'postal'} or "");
  $city    = ($$hash{'city'} or "");
  $phone   = ($$hash{'phone'} or "");
  $mail    = ($$hash{'mail'} or "");
  $web     = ($$hash{'web'} or "");

  $letter = $letter_skeleton;

  unless($name) {
    warn("Name of enterprise [$id] not defined");
    next;
  }
  $recipient = "\n    $name";

  if($tutor) {
    unless($rank) {
      warn("Tutor $tutor rank [$id] not defined");
      next;
    }
  }
  $recipient .= ", \\\\\n    $tutor" if $tutor;
  $recipient .= ", \\\\\n    $job" if $job;

  unless($address && $postal && $city) {
    warn("Incomplete address or address not defined [$id]");
    next;
  }
  $recipient .= ", \\\\\n    $address";
  $recipient .= ", \\\\\n    $postal, $city";

  $recipient .= " \\\\[0.5cm]\n    $phone" if $phone;
  $recipient .= " \\\\\n    $mail" if $mail;
  $recipient .= " \\\\\n    $web" if $web;

  $rankclose = $rank ? ", $rank, " : "Mistress, Mister,";
  $rank = $rank || "Mistress, Mister";

  # create enterprise folder if it doesn't exist
  mkdir $id unless (-d $id);

  # replace in skeleton
  $letter =~ s/\^SENDER/$sender/;
  $letter =~ s/\^RECIPIENT/$recipient/;
  $letter =~ s/\^RANK/$rank/;
  $letter =~ s/\^BEGINDATE/$begindate/;
  $letter =~ s/\^ENDDATE/$enddate/;
  $letter =~ s/\^PERIOD/$period/;
  $letter =~ s/\^RANKCLOSE/$rankclose/;

  # write letter
  unless (-f "$id/LOCK") {
    open OUT, ">$letters_dir/$id/$id.gen.tex";
    print OUT $letter;
    close OUT;
  }

  # write letter makefile
  $makefile_l = <<END;
all: $id.pdf
gen: $id.gen.pdf

$id.pdf: $id.tex
\tpdflatex $id.tex

$id.gen.pdf: $id.gen.tex
\tpdflatex $id.gen.tex

clean:
\t\@echo "Deleting tex compilation files $id"
\t\@rm -f *.log *.aux *.div *.toc *.lot *.lof *.tns *.synctex.gz

END
  open MAKEFILE_L, ">$id/Makefile" || die("Can't write on $id/Makefile");
  print MAKEFILE_L $makefile_l;
  close MAKEFILE_L;

  $makefile_g .= "\n$id: $id/$id.tex\n\t\@cd $id && \${MAKECMD}";
  $makefile_g .= "\n";
  $makefile_g .= "\n$id.gen: $id/$id.gen.tex\n\t\@cd $id && \${MAKECMD_GEN}";
  $makefile_g .= "\n";
}

open MAKEFILE_G, ">Makefile";
print MAKEFILE_G $makefile_g;
close MAKEFILE_G;
