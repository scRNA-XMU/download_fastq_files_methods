# download_fastq_files_methods
two methods for downloading fastq files from GEO or ENA
### **两个下载fastq文件的方法**

#### 方法1：用 sra-toolkit/2.9.2 模块中的 prefetch 工具


##### step 1 载入程序
```
module load sra-toolkit/2.9.2

```
##### step 2 在geo数据库上找到SRR号，下载单个或批量下载
###### 下载单个SRR
```
  prefetch SRR16165156 -O <directory>
```

###### 批量下载：
在GEO官网下载一个类似 SRR_List.txt 的文件,参考：https://mp.weixin.qq.com/s?__biz=MzI1Njk4ODE0MQ==&mid=2247484146&idx=1&sn=16e09b82d048eed1ff6100b22970abd5&chksm=ea1f0470dd688d66bdbfbaf2a2b9ae91f545992469996cfecf407a09492df32b4536fda7ca4f&scene=21#wechat_redirect

然后用 download_SRAdata.sh 脚本批量下载（你需要阅读代码并修改相关参数）
最后在终端运行脚本代码
```
nohup bash 
/cluster/huanglab/cliang/fastq/time_point/download_SRAdata.sh > /cluster/huanglab/cliang/fastq/time_point/download_SRAdata.log &

```

##### step 3 将 .sra 文件转为 .fastq 文件
```
#module load sra-toolkit/2.9.2
#fastq-dump --gzip --split-files <.sra文件的路径>
```

#### 方法2：用perl脚本直接从END数据库下载fastq（不需要.sra转化成.fastq）


```
perl FTPena.pl -i SRR7166333
```

程序部署参考：https://gitee.com/wangshun1121/ASCPsra/tree/master
