#!/usr/bin/perl
package Masspec::Msamanda;

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
  $self->{_name}   = "Msamanda";
  $self->{_suffix} = "_ma";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct ) = get_parameter( $config, $section );
  my $proteindb = $config->{$section}{proteindb} or die "define ${section}::proteindb first";
  my %mgffiles = %{ get_raw_files( $config, $section)};
  my $executable = $config->{$section}{executable};
  

  my $shfile = $self->taskfile( $pbsDir, $task_name );
  open( SH, ">$shfile" ) or die "Cannot create $shfile";
  print SH get_run_command($sh_direct);

  my $threadcount = get_pbs_thread( $config->{$section}{pbs} );
  my @isotopes;
  if ( $config->{$section}{N15} == 1) {
  	@isotopes=("N14","N15"); 
  }
  else {
  	@isotopes=("N14");
  }

  for my $sampleName ( sort keys %mgffiles ) {
    my @sampleFiles = @{ $mgffiles{$sampleName} };
    my $samples = join( " ", @sampleFiles );

    my $pbsFile = $self->pbsfile( $pbsDir, $sampleName );
    $pbsFile = substr($pbsFile,0,-4);
    my $log     = $self->logfile( $logDir, $sampleName );
    $log = substr($log,0,-4);
    
    
    foreach (@isotopes) {
    	my $realpbsfile = $pbsFile."_".$_.".pbs";
    	my $reallog = $log."_".$_.".log";
    	my $pbsName = basename($realpbsfile);
    	my $whichcfg = "cfgfile_".$_;
    	my $cfgfile = $config->{$section}{$whichcfg} or die "define ${section}::cfgfile first";
        my $resultName = substr(basename($samples),0,-4)."_msamanda"."_".$_;    


    open( OUT, ">$realpbsfile" ) or die $!;

    print OUT "$pbsDesc
#SBATCH -o $reallog

$path_file

cd $resultDir 



echo msamanda_start=`date` 

mono $executable $samples $proteindb $cfgfile $resultDir/$resultName

echo finished=`date` 

";
    close(OUT);

    print SH "\$MYCMD ./$pbsName \n";
    print "$realpbsfile created\n";
  }
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
  

  my $result = {};
  for my $sampleName ( keys %rawFiles ) {
    my @resultFiles = ();
    
    $result->{$sampleName} = filter_array( \@resultFiles, $pattern );
  }
  return $result;
}

1;