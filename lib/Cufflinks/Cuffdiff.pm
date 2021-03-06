#!/usr/bin/perl
package Cufflinks::Cuffdiff;

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
  $self->{_name}   = "Cuffdiff";
  $self->{_suffix} = "_cdiff";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct, $cluster ) = get_parameter( $config, $section );

  my $transcript_gtf = parse_param_file( $config, $section, "transcript_gtf", 1 );

  my $faFile = get_param_file( $config->{$section}{fasta_file}, "fasta_file", 1 );

  my $rawFiles = get_raw_files( $config, $section );
  #print Dumper($rawFiles);

  my $groups = get_raw_files( $config, $section, "groups" );
  #print Dumper($groups);

  my $pairs = get_raw_files( $config, $section, "pairs" );
  #print Dumper($pairs);

  my $mapfile = $resultDir . "/${task_name}_group_sample.map";
  open( MAP, ">$mapfile" ) or die "Cannot create $mapfile";
  print MAP "GROUP_INDEX\tSAMPLE_NAME\tGROUP_SAMPLE\tGROUP\tIndex\n";

  my %tpgroups         = ();
  my %group_sample_map = ();
  for my $groupName ( sort keys %{$groups} ) {
    my @samples = @{ $groups->{$groupName} };
    my @gfiles  = ();
    my $index   = 0;
    foreach my $sampleName ( sort @samples ) {
      my @bamFiles = @{ $rawFiles->{$sampleName} };
      push( @gfiles, $bamFiles[0] );
      my $group_index = $groupName . "_" . $index;
      print MAP $group_index . "\t" . $sampleName . "\t" . $groupName . "_" . $sampleName . "\t" . $groupName . "\t" . $index . "\n";
      $group_sample_map{$group_index} = $sampleName;
      $index = $index + 1;
    }
    $tpgroups{$groupName} = join( ",", @gfiles );
  }
  close(MAP);

  my $shfile = $self->taskfile( $pbsDir, $task_name );
  open( SH, ">$shfile" ) or die "Cannot create $shfile";
  print SH get_run_command($sh_direct);

  for my $pairName ( sort keys %{$pairs} ) {
    my ( $ispaired, $gNames ) = get_pair_groups( $pairs, $pairName );
    
    #print Dumper($gNames);
    
    my @groupNames = @{$gNames};
    my @bams       = ();
    foreach my $groupName (@groupNames) {
      push( @bams, $tpgroups{$groupName} );
    }
    my $bamstrs = join( " ", @bams );

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

cuffdiff $option -o . -L $labels -b $faFile $transcript_gtf $bamstrs

echo finished=`date`

exit 0
";

    close(OUT);

    print "$pbsFile created. \n";

    print SH "\$MYCMD ./$pbsName \n";
  }

  print SH "exit 0\n";
  close(SH);

  my $sigfile = $pbsDir . "/${task_name}_sig.pl";
  open( SH, ">$sigfile" ) or die "Cannot create $sigfile";

  print SH "#!/usr/bin/perl
use strict;
use warnings;

use CQS::RNASeq;

my \$config = {
  rename_diff => {
    target_dir => \"${target_dir}/result/comparison\",
    root_dir   => \"${target_dir}/result\",
    gene_only  => 0
  },
};

copy_and_rename_cuffdiff_file(\$config, \"rename_diff\");

1;

";
  close(SH);

  if ( is_linux() ) {
    chmod 0755, $shfile;
  }
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
    push( @resultFiles, $curDir . "/gene_exp.diff" );
    push( @resultFiles, $curDir . "/genes.read_group_tracking" );
    push( @resultFiles, $curDir . "/splicing.diff" );
    push( @resultFiles, $resultDir . "/${task_name}_group_sample.map" );

    $result->{$pairName} = filter_array( \@resultFiles, $pattern );
  }
  return $result;
}

1;
