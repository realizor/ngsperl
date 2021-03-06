#!/usr/bin/perl
package SRA::FastqDump;

use strict;
use warnings;
use File::Basename;
use CQS::PBS;
use CQS::ConfigUtils;
use CQS::SystemUtils;
use CQS::FileUtils;
use CQS::Task;
use CQS::StringUtils;

our @ISA = qw(CQS::Task);

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{_name} = "SRA::FastqDump";
  $self->{_suffix} = "_fd";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct, $cluster ) = get_parameter( $config, $section );

  my $ispaired = $config->{$section}{ispaired};
  if ( !defined $ispaired ) {
    $ispaired = 0;
  }

  my %rawFiles = %{ get_raw_files( $config, $section ) };

  my $shfile = $self->taskfile( $pbsDir, $task_name );
  open( SH, ">$shfile" ) or die "Cannot create $shfile";
  print SH get_run_command($sh_direct) . "\n";

  for my $sampleName ( sort keys %rawFiles ) {
    my @sampleFiles = @{ $rawFiles{$sampleName} };
    my $bamfile     = $sampleFiles[0];

    my $pbsFile = $self->pbsfile($pbsDir, $sampleName);
    my $pbsName = basename($pbsFile);
    my $log     = $self->logfile( $logDir, $sampleName );
    my $logdesp = $cluster->get_log_desc($log);

    print SH "\$MYCMD ./$pbsName \n";

    open( OUT, ">$pbsFile" ) or die $!;

    if ($ispaired) {
      my $fastq1     = $sampleName . "_1.fastq.gz";
      my $fastq2     = $sampleName . "_2.fastq.gz";
      
      print OUT "$pbsDesc
$logdesp

$path_file

cd $resultDir

echo started=`date`

if [ ! -s $fastq1 ]; then
  fastq-dump --split-3 --gzip $bamfile
fi

echo finished=`date`

exit 0 
";
    }
    else {
      my $fastq     = $sampleName . ".fastq.gz";
      print OUT "$pbsDesc
$logdesp

$path_file

cd $resultDir

echo started=`date`

if [ ! -s $fastq ]; then
  fastq-dump --gzip $bamfile
fi

echo finished=`date`

exit 0 
";
    }

    close OUT;

    print "$pbsFile created \n";
  }
  close(SH);

  if ( is_linux() ) {
    chmod 0755, $shfile;
  }

  print "!!!shell file $shfile created, you can run this shell file to submit all Bam2Fastq tasks.\n";

  #`qsub $pbsFile`;
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct ) = get_parameter( $config, $section );

  my $ispaired = $config->{$section}{ispaired};
  if ( !defined $ispaired ) {
    $ispaired = 0;
  }

  my %rawFiles = %{ get_raw_files( $config, $section ) };

  my $result = {};
  for my $sampleName ( keys %rawFiles ) {

    my @resultFiles = ();
    if ($ispaired) {
      push( @resultFiles, $resultDir . "/" . $sampleName . "_1.fastq.gz" );
      push( @resultFiles, $resultDir . "/" . $sampleName . "_2.fastq.gz" );
    }
    else {
      push( @resultFiles, $resultDir . "/" . $sampleName . ".fastq.gz" );
    }

    $result->{$sampleName} = filter_array( \@resultFiles, $pattern );
  }
  return $result;
}

1;
