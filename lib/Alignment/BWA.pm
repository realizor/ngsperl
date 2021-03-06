#!/usr/bin/perl
package Alignment::BWA;

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
  $self->{_name}   = "BWA";
  $self->{_suffix} = "_bwa";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct, $cluster, $thread ) = get_parameter( $config, $section );

  my $selfname = $self->{_name};

  $option = $option . " -M";

  if ( !( $option =~ /-t/ ) ) {
    if ( $thread > 1 ) {
      $option = $option . " -t " . $thread;
    }
  }

  my $bwa_index = $config->{$section}{bwa_index};
  if ( !defined $bwa_index ) {
    $bwa_index = $config->{$section}{fasta_file} or die "define ${section}::bwa_index first";
  }
  my $picard_jar = get_param_file( $config->{$section}{picard_jar}, "picard_jar", 1 );

  my %rawFiles = %{ get_raw_files( $config, $section ) };

  my $shfile = $self->taskfile( $pbsDir, $task_name );
  open( SH, ">$shfile" ) or die "Cannot create $shfile";
  print SH get_run_command($sh_direct);

  for my $sampleName ( sort keys %rawFiles ) {
    my @sampleFiles = @{ $rawFiles{$sampleName} };
    my $samFile     = $sampleName . ".sam";
    my $rgSamFile   = $sampleName . ".rg.sam";
    my $rgBamFile   = $sampleName . ".rg.bam";
    my $bamFile     = $sampleName . ".bam";
    my $tag         = get_bam_tag($sampleName);

    my $sampleFile1 = $sampleFiles[0];

    my $bwa_aln_command;
    if ( scalar(@sampleFiles) == 2 ) {
      my $sampleFile2 = $sampleFiles[1];
      $bwa_aln_command = "bwa mem $option $bwa_index $sampleFile1 $sampleFile2 > $samFile";
    }
    else {
      $bwa_aln_command = "bwa mem $option $bwa_index $sampleFile1 > $samFile";
    }

    my $pbsFile = $self->pbsfile( $pbsDir, $sampleName );
    my $pbsName = basename($pbsFile);
    my $log     = $self->logfile( $logDir, $sampleName );

    my $curDir = create_directory_or_die( $resultDir . "/$sampleName" );

    print SH "\$MYCMD ./$pbsName \n";

    my $log_desc = $cluster->get_log_desc($log);

    open( OUT, ">$pbsFile" ) or die $!;
    print OUT "$pbsDesc
$log_desc
$path_file

cd $curDir

echo bwa_start=`date`

if [ -s $bamFile ]; then
  echo job $selfname has already been done. if you want to do again, delete $bamFile and submit job again.
  exit 0
fi

if [ ! -s $rgBamFile ]; then
  if [ ! -s $rgSamFile ]; then
    if [ ! -s $samFile ]; then
      echo bwa_mem=`date`
      $bwa_aln_command
    fi
    
    if [ -s $samFile ]; then
      java -jar $picard_jar AddOrReplaceReadGroups I=$samFile O=$rgSamFile ID=$sampleName LB=$sampleName SM=$sampleName PL=ILLUMINA PU=ILLUMINA
      if [ -s $rgSamFile ]; then
        rm $samFile
      fi
    fi
  fi

  if [ -s $rgSamFile ]; then
    samtools view -S -b $rgSamFile > $rgBamFile
    if [ -s $rgBamFile ]; then
      rm $rgSamFile
    fi
  fi
fi

if [ -s $rgBamFile ]; then
  samtools sort -@ $thread -m 4G $rgBamFile $sampleName
  if [ -s $bamFile ]; then
    samtools index $bamFile 
    samtools flagstat $bamFile > ${bamFile}.stat 
    rm $rgBamFile
  fi
fi
  
echo finished=`date`

exit 0;
";

    close OUT;

    print "$pbsFile created\n";
  }
  close(SH);

  if ( is_linux() ) {
    chmod 0755, $shfile;
  }

  print "!!!shell file $shfile created, you can run this shell file to submit all BWA tasks.\n";
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct ) = get_parameter( $config, $section );

  my %rawFiles = %{ get_raw_files( $config, $section ) };

  my $result = {};
  for my $sampleName ( keys %rawFiles ) {
    my $bamFile     = "${resultDir}/${sampleName}/${sampleName}.bam";
    my @resultFiles = ();
    push( @resultFiles, $bamFile );
    $result->{$sampleName} = filter_array( \@resultFiles, $pattern );
  }
  return $result;
}

1;
