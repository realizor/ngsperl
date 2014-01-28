#!/usr/bin/perl
package CNV::cnMops;

use strict;
use warnings;
use File::Basename;
use CQS::PBS;
use CQS::ConfigUtils;
use CQS::SystemUtils;
use CQS::FileUtils;
use CQS::Task;
use CQS::NGSCommon;
use CQS::StringUtils;

our @ISA = qw(CQS::Task);

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{_name} = "CNV::cnMops";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct ) = get_parameter( $config, $section );

  my $bedfile = $config->{$section}{bedfile};

  my $isbamsorted = $config->{$section}{isbamsorted};
  if ( !defined($isbamsorted) ) {
    $isbamsorted = 0;
  }

  my $pairmode = $config->{$section}{pairmode};
  if ( !defined($pairmode) ) {
    $pairmode = "unpaired";
  }

  my $rtemplate = dirname(__FILE__) . "/cnMops.r";
  if ( !-e $rtemplate ) {
    die "File not found : " . $rtemplate;
  }

  my $callFile = "${task_name}.call";

  my %rawFiles = %{ get_raw_files( $config, $section ) };

  my $rfile = $resultDir . "/cnmops_${task_name}.r";
  open( R, ">$rfile" ) or die "Cannot create $rfile";
  print R "setwd(\"$resultDir\")
callfile<-\"$callFile\"
prefix<-\"$task_name\"\n";
  if ( defined $bedfile ) {
    print R "hasbed<-1
bedfile<-\"$bedfile\"
";
  }else{
    print R "hasbed<-0\n";
  }
  
  print R "SampleNames <- c( \n";
  my $isfirst = 1;
  for my $sampleName ( sort keys %rawFiles ) {
    if ($isfirst) {
      print R "\"$sampleName\"\n";
      $isfirst = 0;
    }
    else {
      print R ",\"$sampleName\"\n";
    }
  }
  print R ")

BAMFiles <- c(
";

  $isfirst = 1;
  for my $sampleName ( sort keys %rawFiles ) {
    my @sampleFiles = @{ $rawFiles{$sampleName} };
    my $bamFile     = $sampleFiles[0];

    if ( !$isbamsorted ) {
      ( $bamFile, my $bamSorted ) = get_sorted_bam($bamFile);
    }

    if ($isfirst) {
      print R "\"$bamFile\"\n";
      $isfirst = 0;
    }
    else {
      print R ",\"$bamFile\"\n";
    }
  }
  print R ")

";
  open RT, "<$rtemplate" or die $!;
  while (<RT>) {
    if ( $_ =~ '^#' ) {
      next;
    }
    last;
  }
  while (<RT>) {
    print R $_;
  }
  close(RT);
  close R;

  my $pbsFile = "${pbsDir}/cnmops_${task_name}.pbs";
  my $log     = "${logDir}/cnmops_${task_name}.log";

  open( OUT, ">$pbsFile" ) or die $!;
  print OUT "$pbsDesc
#PBS -o $log
#PBS -j oe

$path_file

cd $pbsDir
echo cnmops=`date`
R --vanilla < $rfile 
echo finished=`date`
";
  close OUT;

  print "$pbsFile created\n";
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct ) = get_parameter( $config, $section );
  my $callFile = "${task_name}.call";

  my $result = {};
  push( @resultFiles, $resultDir . "/" . $callFile );
  $result->{$sampleName} = filter_array( \@resultFiles, $pattern );
  
  return $result;
}

1;
