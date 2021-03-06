#!/usr/bin/perl
package QC::RNASeQC;

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
  $self->{_name}   = "RNASeQC";
  $self->{_suffix} = "_qc";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct, $cluster, $thread ) = get_parameter( $config, $section );

  my $faFile         = get_param_file( $config->{$section}{fasta_file},     "fasta_file",     1 );
  my $jar            = get_param_file( $config->{$section}{jar},            "jar",            1 );
  my $transcript_gtf = get_param_file( $config->{$section}{transcript_gtf}, "transcript_gtf", 1 );
  my $sorted = get_option_value($config->{$section}{sorted}, 1);

  my $rawfiles = get_raw_files( $config, $section );

  my $mapfile = $resultDir . "/${task_name}_sample.list";
  open( MAP, ">$mapfile" ) or die "Cannot create $mapfile";
  print MAP "SampleID\tBamFile\tNotes\n";
  for my $sampleName ( sort keys %{$rawfiles} ) {
    my @bamFiles = @{ $rawfiles->{$sampleName} };
    for my $bam (@bamFiles) {
      print MAP $sampleName, "\t", $bam, "\t", $sampleName, "\n";
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

echo RNASeQC=`date`

if [ -s metrics.tsv ]; then
  echo job has already been done. if you want to do again, delete ${resultDir}/metrics.tsv and submit job again.
  exit 0;
fi

java -jar $jar $option -s $mapfile -t $transcript_gtf -ttype 2 -r $faFile -o .

rm refGene.txt*
rm exons.rpkm.gct
rm */*.tmp.txt*
rm */*/perBaseDoC.out

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
