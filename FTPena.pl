#!/usr/bin/env perl
# Wangshun @ Xiamen
# Version 1.1
# 2020.9.2

# 通过FTP的方法直接下载Reads，而不是别的下载工具

use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use Cwd;
use POSIX ":sys_wait_h";
use FindBin qw($Bin);
use Parallel::ForkManager;
use Parallel::Simple qw(prun);

our $work_dir = getcwd;
our $Core = `grep \"process\" /proc/cpuinfo | wc -l `;
chomp($Core); # Core number of server

my $id;
my $list;
my $link;
my $outdir='.';
my $single=0; # 是否是单端数据
my $cpu=4;
my $help;

GetOptions(
  'i|id=s' => \$id,
  'l|list=s' => \$list,
  'o|outdir=s' => \$outdir,
  'p|cpu=i' => \$cpu,
  'h|help' => \$help,
);

my $usage=<<USAGE;

Usage:
  perl $0 -i SRRXXXXXX
  perl $0 -l SraAccList.txt -o ./sequences -p 5 -t 8

  -i|-id	<str> 	   SRA accession ID
  -l|-list 	<file>	   SRA ID list, all IDs should be in one column

  -o|-outdir	<dir>	   Output directory [working directory $work_dir]
  -p|-cpu	<int>	   Threads number used for multi detasets downloading [$Core at most, $cpu default]
  -h|-help                 Show this message

USAGE

if ($help) {
	print $usage;
	exit;
}

unless ($id or $list or $link) {
	print $usage;
	exit;
}

unless(-e $outdir){
  system("mkdir -p $outdir");
}

if($id){
  &download($id,$outdir);
  exit;
}

if($link){
  #帮助文件中暂时把这部分先隐藏吧
  &linkdownload($link,$outdir);
  exit;
}

if(-e $list){
  my @ids=();
  open I,"<$list";
  while (<I>) {
    chomp;
    s/\r//g; #Windows换行符考虑兼容
    push(@ids,(split/\t/)[0]);
  }

  if($cpu>scalar(@ids)){$cpu=scalar(@ids);}

  my $pm=new Parallel::ForkManager($cpu);
  foreach my $id (@ids) {
  	my $pid=$pm->start and next;
  	&download($id,$outdir);
  	$pm->finish;
  };
  $pm->wait_all_children;

  if(-e "$outdir/md5sum"){ # 自动去除重复的md5
    system("sort -k 2 $outdir/md5sum|uniq >$outdir/md5");
    system("rm -f $outdir/md5sum");
  }

}

sub linkdownload{
  #直接给出下载链接，下载SRA数据
  #单纯下载数据，不再直接转换SRA到fastq了
  #这里先暂时用wget来代替。
  my $link=shift;
  my $outdir=shift;
  chdir($outdir);
  my $CMD="wget $link";
  chdir($work_dir);
}

sub download{
  # 下载SRA的核心函数
  my $id=shift;
  my $outdir=shift;

  my $sub1=substr($id,0,3);
  my $sub2 =substr($id,0,6);

  my $link=();

    # print STDERR "Warning: downloading single end sequences from ENA are not taken into consideration\n";
    # ENA可直接下载fq数据，本版本中暂时仅考虑双端序列的情况
    # $link='era-fasp@fasp.sra.ebi.ac.uk:/vol1/fastq';
    my $WebInfo=`curl -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=$id&result=read_run&fields=fastq_ftp,fastq_md5"`;
    $WebInfo=(split/\n/,$WebInfo)[1];
    my ($Links,$md5Line)=(split/\t/,$WebInfo)[-2,-1];
    # 修改ENA Reads获取的API，2020.8.17
      
    my @Links=split/;/,$Links;
    my @md5Values=split/;/,$md5Line;
    my %md5=();
    # note：发现了ENA上居然有数据即保存为单端又保存为双端，例如：SRR6315113
    #       应对这种数据的策略，就是直接把数据判定为双端来下载！
    if(scalar(@Links)>1){
      $link=$Links[-2];
    }else{
      $link=$Links[0];
    }
   
    for(my $i=0;$i<scalar(@Links);$i++){
      if($i<scalar(@Links)-2){next;} # 补上这句话就是应付类似 SRR6315113 的情况
      $Links[$i]=(split/\//,$Links[$i])[-1];
      $md5{$Links[$i]}=$md5Values[$i];
    }

    my $AutoSingle=$single;
    # if(scalar(@md5)==1){$AutoSingle=1;}
    # if(scalar(@md5)==2){$AutoSingle=0;} # 通过读取md5的信息，自动判断数据是单端还是双端
    if($md5{"$id\_1.fastq.gz"} and $md5{"$id\_2.fastq.gz"} ){$AutoSingle=0;}
    elsif($md5{"$id.fastq.gz"}){$AutoSingle=1;} # 不要通过md5是的位置来臆断对应文件！例子：PRJEB13208
      # if(length($id) == 10){
      #     # 10位SRA会在Sub2子文件夹里有000-009的10个额外的子文件夹中
      #     my $tmp=substr($id,9,1);
      #     $link="$link/$sub2/00$tmp/$id/$id";
      # }else{
      #     $link="$link/$sub2/$id/$id";
      # }

    if($AutoSingle){
      # 单端Reads，自动匹配是否是单端序列
      my $md5Value=$md5{"$id.fastq.gz"};
      system("echo \"$md5Value $id.fastq.gz\" >> $outdir/md5sum");
      # my $CMD="$ascp -QT -l 300m -P33001 -i $KEY -k 1 $link.fastq.gz .";
      #my $CMD="$ascp -QT -l 300m -P33001 -i $KEY -k 1 era-fasp\@$link .";
      my $CMD = "wget -c ftp://$link";
      chdir($outdir);
      &GetFile($CMD,"$id.fastq.gz",$md5{"$id.fastq.gz"});
      chdir($work_dir);
    }else{
      # 双端Reads
      my $md5Value=$md5{"$id\_1.fastq.gz"};
      system("echo \"$md5Value $id\_1.fastq.gz\" >> $outdir/md5sum");
      $md5Value=$md5{"$id\_2.fastq.gz"};
      system("echo \"$md5Value $id\_2.fastq.gz\" >> $outdir/md5sum");
      $link=~s/\_1.fastq.gz//;
      #my $CMD1="$ascp -QT -l 300m -P33001 -i $KEY -k 1 era-fasp\@$link\_1.fastq.gz .";
      #my $CMD2="$ascp -QT -l 300m -P33001 -i $KEY -k 1 era-fasp\@$link\_2.fastq.gz .";
      my $CMD1="wget -c ftp://$link\_1.fastq.gz";
      my $CMD2="wget -c ftp://$link\_2.fastq.gz";
      #开双线程下载
      chdir($outdir);
      prun(
    		sub1=>[\&GetFile,($CMD1,"$id\_1.fastq.gz",$md5{"$id\_1.fastq.gz"})],
    		sub2=>[\&GetFile,($CMD2,"$id\_2.fastq.gz",$md5{"$id\_2.fastq.gz"})],
    	)or die(Parallel::Simple::errplus());
      chdir($work_dir);
    }




  sub GetFile{
    # 2019.3.8 添加针对ENA下载数据的MD5校验
    my $CMD=shift; # 文件下载命令
    my $File=shift; # 文件名
    my $md5=shift; # 待校验的md5

    unless(-e $File){&run($CMD);} # 文件没有下载完，则跑
    my $Checked=0;
    my $N=1;
    while($N<5){ # 下载最多尝试5次
      $Checked=`md5sum $File`;
      chomp($Checked);
      $Checked=(split/\ /,$Checked)[0];
      if($md5 eq $Checked){
        print STDERR "$File downloaded!\n\n";
        last;
      }
      else{
        $N++;
        system("rm -f $File");
        print STDERR "$File check failed. True md5: $md5; Checked: $Checked\n";
        &run($CMD); # md5校验失败，则删除目标文件，重新下载
        next;
      }
    }
    unless($md5 eq $Checked){
      print STDERR "!!! $File check failed, please check the file manually\n";
    }
  }

  sub run{
  	my $CMD = shift;
    my $log="$CMD\nStart:";
    $log.=localtime();
    $log.="\n";
  	$log.=`$CMD`;
    $log.="End:";
    $log.=localtime();
    $log.="\n";
    print $log;
  }
}
