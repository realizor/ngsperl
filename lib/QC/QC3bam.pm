#!/usr/bin/perl
package QC::QC3bam;

use strict;
use warnings;
use File::Basename;
use CQS::PBS;
use CQS::ConfigUtils;
use CQS::SystemUtils;
use CQS::FileUtils;
use CQS::NGSCommon;
use CQS::StringUtils;
use CQS::UniqueTask;

our @ISA = qw(CQS::UniqueTask);

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{_name}   = "QC3bam";
  $self->{_suffix} = "_qc3";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct, $cluster ) = get_parameter( $config, $section );

  my $transcript_gtf = get_param_file( $config->{$section}{transcript_gtf}, "transcript_gtf", 1 );
  my $qc3_perl = get_param_file( $config->{$section}{qc3_perl}, "qc3_perl", 1 );

  my $rawfiles = get_raw_files( $config, $section );

  my $mapfile = $resultDir . "/${task_name}_sample.list";
  open( MAP, ">$mapfile" ) or die "Cannot create $mapfile";
  for my $sampleName ( sort keys %{$rawfiles} ) {
    my @bamFiles = @{ $rawfiles->{$sampleName} };
    for my $bam (@bamFiles) {
      print MAP $bam, "\t", $sampleName, "\n";
    }
  }
  close(MAP);

  my $pbsFile = $self->pbsfile( $pbsDir, $task_name );
  my $pbsName = basename($pbsFile);
  my $log     = $self->logfile( $logDir, $task_name );

  my $log_desc = $cluster->get_log_desc($log);

  open( OUT, ">$pbsFile" ) or die $!;
  print OUT "$pbsDesc
$log_desc

$path_file

cd $resultDir

echo QC3bam=`date`
 
perl $qc3_perl $option -m b -i $mapfile -g $transcript_gtf -o $resultDir

echo finished=`date`

exit 0
";
  close(OUT);

  print "$pbsFile created. \n";
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct ) = get_parameter( $config, $section );

  my $result      = {};
  my @resultFiles = ();
  push( @resultFiles, $resultDir . "/metrics.tsv" );
  $result->{$task_name} = filter_array( \@resultFiles, $pattern );

  return $result;
}

1;
