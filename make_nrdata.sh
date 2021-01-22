#!/bin/bash

# ----- usage ------ #
function usage()
{
	echo "Make_NRdata v0.20 [Jul-01-2019] "
	echo "    A fully automatic pipeline to generate NR90 and NR70 for BuildAli2. "
	echo ""
	echo "USAGE:  ./make_nrdata.sh <-i nr> [-o out_root] [-c CPU_num] [-K remove_tmp] [-H home] "
	echo "Options:"
	echo ""
	echo "***** required arguments *****"
	echo "-i nr             : Input NR database in FASTA format. [type NULL to download] "
	echo ""
	echo "***** optional arguments (main) *****"
	echo "-o out_root       : Default output would the current directory. [default = './NR_`date '+%Y%m%d'`'] "
	echo ""
	echo "-c CPU_num        : Number of processors. [default = 24]"
	echo ""
	echo "-K remove_tmp     : Remove temporary folder or not. [default = 1 to remove] "
	echo "                    set 2 to remove nr, nr90, and nr70 while only keep files for blast "
	echo ""
	echo "***** home directory *****"
	echo "-H home           : home directory of DeepSimulator. [default = 'current directory'] "
	echo ""
	exit 1
}


#------------------------------------------------------------#
##### ===== get pwd and check BlastSearchHome ====== #########
#------------------------------------------------------------#

#------ current directory ------#
curdir="$(pwd)"

#-------- check usage -------#
if [ $# -lt 1 ];
then
        usage
fi


#---------------------------------------------------------#
##### ===== All arguments are defined here ====== #########
#---------------------------------------------------------#

#------- required arguments ------------#
input_nr=""         #-> default is NULL to download latest
out_root=""         #-> default is './NR_${DATE}'
THREAD_NUM=24       #-> this is the thread (or, CPU) number
kill_tmp=1          #-> default: kill temporary root
home=`dirname $0`   #-> home directory

#------- parse arguments ---------------#
while getopts ":i:o:c:K:H:" opt;
do
	case $opt in
	#-> required arguments
	i)
		input_nr=$OPTARG
		;;
	#-> optional arguments
	o)
		out_root=$OPTARG
		;;
	c)
		THREAD_NUM=$OPTARG
		;;
	K)
		kill_tmp=$OPTARG
		;;
	#-> home directory
	H)
		home=$OPTARG
		;;
	#-> default
	\?)
		echo "Invalid option: -$OPTARG" >&2
		exit 1
		;;
	:)
		echo "Option -$OPTARG requires an argument." >&2
		exit 1
		;;
	esac
done


#---------------------------------------------------------#
##### ===== Part 0: initial argument check ====== #########
#---------------------------------------------------------#

# ------ check home directory ---------- #
if [ ! -d "$home" ]
then
	echo "home directory $home not exist " >&2
	exit 1
fi
home=`readlink -f $home`

# ------ check output directory -------- #
DATE=`date '+%Y%m%d'`
if [ "$out_root" == "" ]
then
	out_root=NR_${DATE}
fi
mkdir -p $out_root
out_root=`readlink -f $out_root`


#--------------------------------------------------------#
##### ===== Part 1: automatic NRXX update ====== #########
#--------------------------------------------------------#

#-> 1. download the latest NR database: 
echo "step 1: download the latest NR database"
down=0
if [ ! -s "$input_nr" ]
then 
	wget ftp://ftp.ncbi.nlm.nih.gov/blast/db/FASTA/nr.gz
	gunzip nr.gz
	input_nr=nr
	down=1
fi

#-> 2. construct NR90:
echo "step 2: construct NR90"
rm -rf tmp
$home/bin/mmseqs createdb $input_nr nrdb
$home/bin/mmseqs linclust nrdb nrdb_clu tmp --min-seq-id 0.9 --threads $THREAD_NUM
$home/bin/mmseqs result2repseq nrdb nrdb_clu nrdb_clu_rep
$home/bin/mmseqs result2flat nrdb nrdb nrdb_clu_rep nrdb_clu_rep.fasta --use-fasta-header
rm -rf tmp
mv nrdb_clu_rep.fasta nr90

#-> 3. construct NR70:
echo "step 3: construct NR90"
rm -rf tmp
$home/bin/mmseqs createdb nr90 nr90db
$home/bin/mmseqs linclust nr90db nr90db_clu tmp --min-seq-id 0.7 --threads $THREAD_NUM
$home/bin/mmseqs result2repseq nr90db nr90db_clu nr90db_clu_rep
$home/bin/mmseqs result2flat nr90db nr90db nr90db_clu_rep nr90db_clu_rep.fasta --use-fasta-header
rm -rf tmp
mv nr90db_clu_rep.fasta nr70

#-> 4. BLAST formatdb:
echo "step 4: BLAST formatdb"
$home/BLAST/bin/formatdb -i nr90 -p T -n nr90
mv formatdb.log nr90.formatdb
$home/BLAST/bin/formatdb -i nr70 -p T -n nr70
mv formatdb.log nr70.formatdb

#-> 5. get sequence number:
nr90_num=`grep "^Formatted" nr90.formatdb | awk 'BEGIN{a=0}{a+=$2}END{print a}'`
nr70_num=`grep "^Formatted" nr70.formatdb | awk 'BEGIN{a=0}{a+=$2}END{print a}'`


#----------- move generated NRXX files --------------#
#-> nr90
mv nr90*.phr $out_root
mv nr90*.pin $out_root
mv nr90*.psq $out_root
mv nr90.formatdb $out_root
if [ -s "nr90.pal" ]
then
	mv nr90.pal $out_root
fi

#-> nr70
mv nr70*.phr $out_root
mv nr70*.pin $out_root
mv nr70*.psq $out_root
mv nr70.formatdb $out_root
if [ -s "nr70.pal" ]
then
	mv nr70.pal $out_root
fi


#----------- remove temporary files/folders --------------#
if [ $kill_tmp -ge 1 ]
then
	#-> remove nrdb
	rm -f nrdb_h nrdb
	rm -f nrdb*
	#-> remove nr90 temporary files
	rm -f nrdb_clu.*
	rm -f nrdb_clu_rep*
	#-> remove nr90db
	rm -f nr90db_h nr90db
	rm -f nr90db*
	#-> remove nr70 temporary files
	rm -f nr90db_clu.*
	rm -f nr90db_clu_rep*
fi
if [ $kill_tmp -ge 2 ]
then
	#-> remove nr
	if [ $down -eq 1 ]
	then
		rm -f nr
	fi
	#-> remove nr90
	rm -f nr90
	#-> remove nr70
	rm -f nr70
fi

# ========= exit 0 =========== #
exit 0


