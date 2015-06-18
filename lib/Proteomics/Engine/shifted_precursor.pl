#!/usr/bin/perl
use strict;
use warnings;

use CQS::ClassFactory;
use CQS::FileUtils;
use CQS::SystemUtils;
use CQS::ConfigUtils;

my $target_dir     = "/scratch/cqs/shengq1/proteomics/20150608_shifted_precursor";
my $msgf_jar       = "/scratch/cqs/shengq1/local/bin/MSGFPlus/MSGFPlus.jar";
my $msamanda_exe   = "/home/zhangp2/local/bin/msamanda/MSAmanda.exe";
my $proteomicstools = "/home/shengq1/proteomicstools/ProteomicsTools.exe";
my $mod_file       = "/scratch/cqs/shengq1/local/bin/MSGFPlus/Mods.txt";
my $msamanda_config = "/scratch/cqs/zhangp2/parameter/msamanda_settings_shifted.xml";
my $database_human = "/gpfs21/scratch/cqs/shengq1/proteomics/shifted/rev_Human_uniprot_sprot_v20120613.fasta";
my $database_yeast = "/gpfs21/scratch/cqs/shengq1/proteomics/shifted/rev_Yeast_uniprot_v20120613.fasta";
my $database_ecoli = "/gpfs21/scratch/cqs/shengq1/proteomics/shifted/rev_Ecoli_uniprot_v20120613_P4431.fasta";
my $email          = "pan.zhang\@vanderbilt.edu";

my $config = {
  general           => { task_name => "ShiftedTargetDecoy" },
  Elite_CIDIT_Human_Msamanda => {
    class      => "Proteomics::Engine::Msamanda",
    perform    => 1,
    target_dir => "${target_dir}/Elite_CIDIT_Human",
    option     => "",
    source     => {
      "Elite_CIDIT_Human.plus0.1dalton" => ["/gpfs21/scratch/cqs/shengq1/proteomics/shifted/Elite_CIDIT_Human.plus0.1dalton.mgf"],
      "Elite_CIDIT_Human.plus10dalton"  => ["/gpfs21/scratch/cqs/shengq1/proteomics/shifted/Elite_CIDIT_Human.plus10dalton.mgf"],
    },
    executable => $msamanda_exe,
    cfgfile => $msamanda_config,
    database  => $database_human,
    sh_direct => 0,
    pbs       => {
      "email"    => $email,
      "nodes"    => "1:ppn=8",
      "walltime" => "72",
      "mem"      => "40gb"
    },
  },
  Fusion_CIDIT_Human_Msamanda => {
    class      => "Proteomics::Engine::Msamanda",
    perform    => 1,
    target_dir => "${target_dir}/Fusion_CIDIT_Human",
    option     => "",
    source     => {
      "Fusion_CIDIT_Human.plus0.1dalton" => ["/gpfs21/scratch/cqs/shengq1/proteomics/shifted/Fusion_CIDIT_Human.plus0.1dalton.mgf"],
      "Fusion_CIDIT_Human.plus10dalton"  => ["/gpfs21/scratch/cqs/shengq1/proteomics/shifted/Fusion_CIDIT_Human.plus10dalton.mgf"],
    },
    executable => $msamanda_exe,
    cfgfile => $msamanda_config,
    database  => $database_human,
    sh_direct => 0,
    pbs       => {
      "email"    => $email,
      "nodes"    => "1:ppn=8",
      "walltime" => "72",
      "mem"      => "40gb"
    },
  },
  Fusion_HCDIT_Yeast_Msamanda => {
    class      => "Proteomics::Engine::Msamanda",
    perform    => 1,
    target_dir => "${target_dir}/Fusion_HCDIT_Yeast",
    option     => "",
    source     => {
      "Fusion_HCDIT_Yeast.plus0.1dalton" => ["/gpfs21/scratch/cqs/shengq1/proteomics/shifted/Fusion_HCDIT_Yeast.plus0.1dalton.mgf"],
      "Fusion_HCDIT_Yeast.plus10dalton"  => ["/gpfs21/scratch/cqs/shengq1/proteomics/shifted/Fusion_HCDIT_Yeast.plus10dalton.mgf"],
    },
    executable => $msamanda_exe,
    cfgfile => $msamanda_config,
    database  => $database_yeast,
    sh_direct => 0,
    pbs       => {
      "email"    => $email,
      "nodes"    => "1:ppn=8",
      "walltime" => "72",
      "mem"      => "40gb"
    },
  },
  Fusion_HCDOT_Human_Msamanda => {
    class      => "Proteomics::Engine::Msamanda",
    perform    => 1,
    target_dir => "${target_dir}/Fusion_HCDOT_Human",
    option     => "",
    source     => {
      "Fusion_HCDOT_Human.plus0.1dalton" => ["/gpfs21/scratch/cqs/shengq1/proteomics/shifted/Fusion_HCDOT_Human.plus0.1dalton.mgf"],
      "Fusion_HCDOT_Human.plus10dalton"  => ["/gpfs21/scratch/cqs/shengq1/proteomics/shifted/Fusion_HCDOT_Human.plus10dalton.mgf"],
    },
    executable => $msamanda_exe,
    cfgfile => $msamanda_config,
    database  => $database_human,
    sh_direct => 0,
    pbs       => {
      "email"    => $email,
      "nodes"    => "1:ppn=8",
      "walltime" => "72",
      "mem"      => "40gb"
    },
  },
  QExactive_HCDOT_Human_Msamanda => {
    class      => "Proteomics::Engine::Msamanda",
    perform    => 1,
    target_dir => "${target_dir}/QExactive_HCDOT_Human",
    option     => "",
    source     => {
      "QExactive_HCDOT_Human.plus0.1dalton" => ["/gpfs21/scratch/cqs/shengq1/proteomics/shifted/QExactive_HCDOT_Human.plus0.1dalton.mgf"],
      "QExactive_HCDOT_Human.plus10dalton"  => ["/gpfs21/scratch/cqs/shengq1/proteomics/shifted/QExactive_HCDOT_Human.plus10dalton.mgf"],
    },
    executable => $msamanda_exe,
    cfgfile => $msamanda_config,
    database  => $database_human,
    sh_direct => 0,
    pbs       => {
      "email"    => $email,
      "nodes"    => "1:ppn=8",
      "walltime" => "72",
      "mem"      => "40gb"
    },
  },
  QTOF_Ecoli_Msamanda => {
    class      => "Proteomics::Engine::Msamanda",
    perform    => 1,
    target_dir => "${target_dir}/QTOF_Ecoli",
    option     => "",
    source     => {
      "QTOF_Ecoli.plus0.1dalton" => ["/gpfs21/scratch/cqs/shengq1/proteomics/shifted/QTOF_Ecoli.plus0.1dalton.mgf"],
      "QTOF_Ecoli.plus10dalton"  => ["/gpfs21/scratch/cqs/shengq1/proteomics/shifted/QTOF_Ecoli.plus10dalton.mgf"],
    },
    executable => $msamanda_exe,
    cfgfile => $msamanda_config,
    database  => $database_ecoli,
    sh_direct => 0,
    pbs       => {
      "email"    => $email,
      "nodes"    => "1:ppn=8",
      "walltime" => "72",
      "mem"      => "40gb"
    },
  },
  MSGFPlus_Distiller => {
    class      => "Proteomics::Distiller::PSMDistiller",
    perform    => 1,
    target_dir => "${target_dir}/PSMDistillerMSGFPlus",
    option     => "",
    source_ref     => [ "Elite_CIDIT_Human_Msamanda", "Fusion_CIDIT_Human_Msamanda", "Fusion_HCDIT_Yeast_Msamanda", "Fusion_HCDIT_Yeast_Msamanda", "Fusion_HCDOT_Human_Msamanda", "QExactive_HCDOT_Human_Msamanda", "QTOF_Ecoli_Msamanda" ],
    proteomicstools  => $proteomicstools,
    sh_direct => 1,
    pbs       => {
      "email"    => $email,
      "nodes"    => "1:ppn=8",
      "walltime" => "72",
      "mem"      => "40gb"
    },
  },
  sequencetask => {
    class      => "CQS::SequenceTask",
    perform    => 1,
    target_dir => "${target_dir}/sequencetask",
    option     => "",
    source     => { step_1 => [ "Elite_CIDIT_Human_Msamanda", "Fusion_CIDIT_Human_Msamanda", "Fusion_HCDIT_Yeast_Msamanda", "Fusion_HCDIT_Yeast_Msamanda", "Fusion_HCDOT_Human_Msamanda", "QExactive_HCDOT_Human_Msamanda", "QTOF_Ecoli_Msamanda" ], },
    sh_direct  => 1,
    pbs        => {
      "email"    => $email,
      "nodes"    => "1:ppn=8",
      "walltime" => "72",
      "mem"      => "40gb"
    },
  },
};

performConfig($config);

1;