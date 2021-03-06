#!/usr/bin/perl
package Picard::ReorderSam;

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
  $self->{_name} = "ReorderSam";
  $self->{_suffix} = "_ro";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct, $cluster ) = get_parameter( $config, $section );

  my $faFile = get_param_file( $config->{$section}{fasta_file}, "fasta_file", 1 );
  my $picard_jar = get_param_file( $config->{$section}{picard_jar}, "picard_jar", 1 );

  my $shfile = $self->taskfile( $pbsDir, $task_name );
  open( SH, ">$shfile" ) or die "Cannot create $shfile";
  print SH get_run_command($sh_direct);

  my %rawFiles = %{ get_raw_files( $config, $section ) };

  for my $sampleName ( sort keys %rawFiles ) {
    my @sampleFiles = @{ $rawFiles{$sampleName} };
    my $sampleFile  = $sampleFiles[0];

    my $pbsFile = $self->pbsfile( $pbsDir, $sampleName );
    my $pbsName = basename($pbsFile);
    my $log     = $self->logfile( $logDir, $sampleName );

    my $curDir = create_directory_or_die( $resultDir . "/$sampleName" );

    my $finalFile = "${sampleName}.reordered.bam";

    my $log_desc = $cluster->get_log_desc($log);

    open( OUT, ">$pbsFile" ) or die $!;
    print OUT "$pbsDesc
$log_desc

$path_file

cd $curDir 

if [ -s $finalFile ]; then
  if [ ! -s ${finalFile}.bai ]; then
    samtools index $finalFile
    exit 0;
  fi
  echo job has already been done. if you want to do again, delete ${curDir}/${finalFile} and submit job again.
  exit 0;
fi

java -jar $picard_jar ReorderSam I=${sampleFile} O=${finalFile} R=${faFile}

samtools index $finalFile

exit 0;
";
    close(OUT);

    print SH "\$MYCMD ./$pbsName \n";
    print "$pbsFile created\n";
  }
  print SH "exit 0\n";
  close(SH);

  if ( is_linux() ) {
    chmod 0755, $shfile;
  }

  print "!!!shell file $shfile created, you can run this shell file to submit all tasks.\n";
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct ) = get_parameter( $config, $section );

  my %rawFiles = %{ get_raw_files( $config, $section ) };
  my $sort_by_query = get_option_value( $config->{$section}{sort_by_query}, 0 );

  my $result = {};
  for my $sampleName ( keys %rawFiles ) {
    my $finalFile   = "${sampleName}.reordered.bam";
    my @resultFiles = ();
    push( @resultFiles, "${resultDir}/${sampleName}/${finalFile}" );
    $result->{$sampleName} = filter_array( \@resultFiles, $pattern );
  }
  return $result;
}

1;
