#!/usr/bin/perl
package CQS::FastqIdentical;

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
  $self->{_name} = "FastqIdentical";
  $self->{_suffix} = "_IQB";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct, $cluster ) = get_parameter( $config, $section );

  my $cqstools  = get_cqstools( $config, $section, 1 );
  my $extension = get_option($config, $section, "extension");

  my $minlen = $config->{$section}{minlen};
  if ( defined $minlen ) {
    $minlen = "-l $minlen";
  }
  else {
    $minlen = "";
  }

  my %rawFiles = %{ get_raw_files( $config, $section ) };

  my $shfile = $self->taskfile( $pbsDir, $task_name );
  open( SH, ">$shfile" ) or die "Cannot create $shfile";
  print SH get_run_command($sh_direct);

  for my $sampleName ( sort keys %rawFiles ) {
    my @sampleFiles = @{ $rawFiles{$sampleName} };
    my $finalFile   = $sampleName . $extension;

    my $pbsFile = $self->pbsfile( $pbsDir, $sampleName );
    my $pbsName = basename($pbsFile);
    my $log     = $self->logfile( $logDir, $sampleName );
    
    print SH "\$MYCMD ./$pbsName \n";

    my $log_desc = $cluster->get_log_desc($log);

    open( OUT, ">$pbsFile" ) or die $!;
    print OUT "$pbsDesc
$log_desc

$path_file

cd $resultDir

if [ -s $finalFile ]; then
  echo job has already been done. if you want to do again, delete ${resultDir}/${finalFile} and submit job again.
  exit 0;
fi

";
    if ( scalar(@sampleFiles) == 1 ) {
      print OUT "mono-sgen $cqstools fastq_identical $option -i $sampleFiles[0] $minlen -o $finalFile \n";
    }
    else {
      my $outputFiles = "";
      for my $sampleFile (@sampleFiles) {
        my $outputFile = change_extension_gzipped(basename($sampleFile), $extension);
        $outputFiles = $outputFiles . " " . $outputFile;
        print OUT "mono-sgen $cqstools fastq_identical -i $sampleFile $minlen -o $outputFile \n";
      }
    }
    print OUT "
echo finished=`date`

exit 0 
";

    close OUT;

    print "$pbsFile created \n";
  }
  close(SH);

  if ( is_linux() ) {
    chmod 0755, $shfile;
  }

  print "!!!shell file $shfile created, you can run this shell file to submit all bwa tasks.\n";

  #`qsub $pbsFile`;
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct ) = get_parameter( $config, $section );

  my $extension = get_option($config, $section, "extension");
  my $merge_result = get_option( $config, $section, "merge_result", 0 );

  my %rawFiles = %{ get_raw_files( $config, $section ) };

  my $result = {};
  for my $sampleName ( keys %rawFiles ) {
    my @sampleFiles = @{ $rawFiles{$sampleName} };
    my $finalFile   = $resultDir . "/" . $sampleName . $extension;
    my @resultFiles = ();

    if ( scalar(@sampleFiles) == 1 ) {
      push( @resultFiles, $finalFile );
      push( @resultFiles, change_extension( $finalFile, ".dupcount" ) );
    }
    else {
      for my $sampleFile (@sampleFiles) {
        my $fileName = basename($sampleFile);
        my $outputFile = $resultDir . "/" . change_extension( $fileName, $extension );
        push( @resultFiles, $outputFile );
        push( @resultFiles, change_extension( $outputFile, ".dupcount" ) );
      }
    }

    $result->{$sampleName} = filter_array( \@resultFiles, $pattern );
  }
  return $result;
}

1;
