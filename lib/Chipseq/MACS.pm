#!/usr/bin/perl
package Chipseq::MACS;

use strict;
use warnings;
use File::Basename;
use CQS::PBS;
use CQS::ConfigUtils;
use CQS::SystemUtils;
use CQS::FileUtils;
use CQS::PairTask;
use CQS::NGSCommon;
use Data::Dumper;

our @ISA = qw(CQS::PairTask);

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{_name}   = "Chipseq::MACS";
  $self->{_suffix} = "_macs";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct, $cluster ) = get_parameter( $config, $section );

  my $rawFiles = get_raw_files( $config, $section );

  #print Dumper($rawFiles);

  my $groups = get_raw_files( $config, $section, "groups" );

  #print Dumper($groups);

  my $pairs = get_raw_files( $config, $section, "pairs" );

  #print Dumper($pairs);

  my $shfile = $self->taskfile( $pbsDir, $task_name );
  open( SH, ">$shfile" ) or die "Cannot create $shfile";
  print SH get_run_command($sh_direct);

  for my $pairName ( sort keys %{$pairs} ) {
    my ( $ispaired, $gNames ) = get_pair_groups( $pairs, $pairName );
    my @groupNames   = @{$gNames};
    my $groupControl = $groups->{ $groupNames[0] };
    my $groupSample  = $groups->{ $groupNames[1] };

    my $control = $rawFiles->{ $groupControl->[0] }[0];
    my $sample  = $rawFiles->{ $groupSample->[0] }[0];

    #print $pairName, ": ", $sample, " vs ", $control, "\n";

    my $pbsFile = $self->pbsfile( $pbsDir, $pairName );
    my $pbsName = basename($pbsFile);
    my $log     = $self->logfile( $logDir, $pairName );

    my $curDir = create_directory_or_die( $resultDir . "/$pairName" );

    my $labels = join( ",", @groupNames );

    my $log_desc = $cluster->get_log_desc($log);

    open( OUT, ">$pbsFile" ) or die $!;
    print OUT "$pbsDesc
$log_desc

$path_file

cd $curDir

if [ -s gene_exp.diff ];then
  echo job has already been done. if you want to do again, delete ${curDir}/gene_exp.diff and submit job again.
  exit 0;
fi

echo MACS_start=`date`

macs14 $option -t $sample -c $control -n $pairName

echo MACS_end=`date`

exit 0
";

    close(OUT);

    print "$pbsFile created. \n";

    print SH "\$MYCMD ./$pbsName \n";
  }

  print SH "exit 0\n";
  close(SH);

  print "!!!shell file $shfile created, you can run this shell file to submit tasks.\n";
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct ) = get_parameter( $config, $section );

  my $pairs = get_raw_files( $config, $section, "pairs" );

  my $result = {};
  for my $pairName ( sort keys %{$pairs} ) {
    my $curDir      = $resultDir . "/$pairName";
    my @resultFiles = ();
    push( @resultFiles, $curDir . "/${pairName}_peaks.bed" );
    push( @resultFiles, $curDir . "/${pairName}_MACS_wiggle/treat" );

    $result->{$pairName} = filter_array( \@resultFiles, $pattern );
  }
  return $result;
}

1;
