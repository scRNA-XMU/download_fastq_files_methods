#!/bin/bash

### Create: cliang
### Date: 2019-9-4
### 
###
###ps -aux|grep cellranger_aggr.sh|grep -v grep
###nohup bash /cluster/huanglab/metong/database_enhancer_project/CRC_cellines/codes/codes_H3K27ac/download_SRAdata.sh > /cluster/huanglab/metong/database_enhancer_project/CRC_cellines/codes/codes_H3K27ac/download_SRAdata.log &
### --nosecondary
#conda install -c bioconda sra-tools
# 下载 aspera connect
#curl -O http://download.asperasoft.com/download/sw/connect/3.6.1/aspera-connect-3.6.1.110647-linux-64.tar.gz
# 解压 
#tar -zxvf aspera-connect-3.6.1.110647-linux-64.tar.gz
# 安装
#sh aspera-connect-3.6.1.110647-linux-64.sh
# 添加到环境变量
#export PATH="/home/xjf/tools/aspera-connect-3.6.1.110647-linux-64.sh:$PATH"

wkd=/cluster/huanglab/cliang/fastq/time_point/
cd $wkd/raw

module load sra-toolkit/2.9.2


cat /cluster/huanglab/cliang/fastq/time_point/SRR_List.txt |while read i
do prefetch $i -O `pwd` && echo "** ${i}.sra done **"
done




# `--gzip`将生成的结果fastq文件进行压缩
# `--split-3`其实有点复杂：首先它是分割的意思，`-3`实际上指的是分成3个文件，它诞生的时间比较早，是在1000 Genome的Phase1阶段产生的。
#如果结果发现只有一个文件，说明数据不是双端(第三个文件太大会覆盖前两个)；
#如果结果有两个文件，说明是双端文件并且数据质量比较高(没有低质量的reads或者长度小于20bp的reads)；
#如果结果有三个文件，说明是双端文件，但是有的数据质量不高，存在trim的结果，第三个文件的名字一般是：`<srr_id>.fastq`， 而且文件也不大，基本可以忽略
#- -A指定输出的文件名

#time fastq-dump --gzip --split-3 SRR3157811.sra
#time fastq-dump --gzip --split-3 SRR3157852.sra