#!/usr/bin/perl
package Annotation::Annovar;

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
  $self->{_name} = "Annovar";
  $self->{_suffix} = "_ann";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct, $cluster ) = get_parameter( $config, $section );

  my $buildver = $config->{$section}{buildver} or die "buildver is not defined in $section";
  $option = "-buildver $buildver $option";

  my $annovarDB = $config->{$section}{annovar_db} or die "annovar_db is not defined in $section";
  my $isvcf = $config->{$section}{isvcf};
  if ( !defined $isvcf ) {
    $isvcf = 0;
  }

  my $cqstools = get_cqstools( $config, $section, 0 );
  my $affyFile = get_param_file( $config->{$section}{affy_file}, "affy_file", 0 );

  my $rawFiles = get_raw_files( $config, $section );

  my $shfile = $self->taskfile( $pbsDir, $task_name );
  open( SH, ">$shfile" ) or die "Cannot create $shfile";
  print SH get_run_command($sh_direct);

  my $listfile = $self->getfile( $resultDir, $task_name, ".list", 0 );
  open( LT, ">$listfile" ) or die "Cannot create $listfile";

  for my $sampleName ( sort keys %{$rawFiles} ) {
    my @sampleFiles = @{ $rawFiles->{$sampleName} };

    my $pbsFile = $self->pbsfile($pbsDir, $sampleName);
    my $pbsName = basename($pbsFile);
    my $log     = $self->logfile( $logDir, $sampleName );

    my $curDir = create_directory_or_die( $resultDir . "/$sampleName" );

    my $log_desc = $cluster->get_log_desc($log);

    open( OUT, ">$pbsFile" ) or die $!;
    print OUT "$pbsDesc
$log_desc

$path_file

cd $curDir
";

    for my $sampleFile (@sampleFiles) {
      my ( $filename, $dir ) = fileparse($sampleFile);

      if ( $dir eq $curDir ) {
        $sampleFile = $filename;
      }

      my $annovar = change_extension( $filename, ".annovar" );
      my $result  = "${annovar}.${buildver}_multianno.txt";
      my $final   = $annovar . ".final.tsv";
      my $excel   = $final . ".xls";

      my $vcf;
      my $passinput;
      if ($isvcf) {
        $passinput = change_extension( $filename, ".avinput" );
        $vcf = "convert2annovar.pl -format vcf4old ${sampleFile} | cut -f1-7 > $passinput ";
      }
      else {
        $passinput = $sampleFile;
        $vcf       = "";
      }

      print OUT "
if [ ! -s $result ]; then 
  $vcf
  table_annovar.pl $passinput $annovarDB $option --outfile $annovar 
fi

if [[ -s $result && ! -s $final ]]; then
  grep \"^##\" ${sampleFile} > ${final}.header
  grep -v \"^##\" ${sampleFile} | cut -f8- > ${sampleFile}.clean
  grep -v \"^##\" ${result} > ${result}.clean
  paste ${result}.clean ${sampleFile}.clean > ${final}.data
  cat ${final}.header ${final}.data > $final
  rm ${sampleFile}.clean ${result}.clean ${final}.header ${final}.data
fi
";

      if ( defined $cqstools ) {
        my $affyoption = defined($affyFile) ? "-a $affyFile" : "";
        print OUT "
if [ -s $final ]; then
  rm $passinput $result
fi

if [[ -s $final && ! -s $excel ]]; then
  mono-sgen $cqstools annovar_refine -i $final $affyoption -o $excel
fi
";
      }
      
      print LT "${curDir}/${result}\n";
    }
    print OUT "
echo finished=`date`

exit 0
";
    close(OUT);

    print "$pbsFile created. \n";

    print SH "\$MYCMD ./$pbsName \n";
    
  }
  close(LT);

  print SH "exit 0\n";
  close(SH);

  if ( is_linux() ) {
    chmod 0755, $shfile;
  }
  print "!!!shell file $shfile created, you can run this shell file to submit Annovar tasks.\n";
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct ) = get_parameter( $config, $section );

  my $buildver = $config->{$section}{buildver} or die "buildver is not defined in $section";
  my $rawFiles = get_raw_files( $config, $section );
  my $cqstools = get_cqstools( $config, $section, 0 );

  my $result = {};
  for my $sampleName ( sort keys %{$rawFiles} ) {
    my @sampleFiles = @{ $rawFiles->{$sampleName} };
    my $curDir      = $resultDir . "/$sampleName";
    my @resultFiles = ();
    for my $sampleFile (@sampleFiles) {
      my $annovar = change_extension( $sampleFile, ".annovar" );
      my $final   = $annovar . ".final.txt";
      my $result  = "${annovar}.${buildver}_multianno.txt";
      if ( defined $cqstools ) {
        my $excel = $final . ".xls";
        push( @resultFiles, $curDir . "/$excel" );
      }
      push( @resultFiles, $curDir . "/$final" );
      push( @resultFiles, $curDir . "/$result" );
    }
    $result->{$sampleName} = filter_array( \@resultFiles, $pattern );
  }
  return $result;
}

1;
