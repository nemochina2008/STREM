#!/bin/bash

if [ -z "$1" ]
then
  echo "Missing parameter 'exec path'".
  exit
fi
if [ -z "$2" ]
then
  echo "Missing parameter 'scenario'".
  exit
fi
if [ -z "$3" ]
then
  echo "Missing parameter 'iterations'".
  exit
fi
if [ -z "$4" ]
then
  echo "Missing parameter 'max_nodes'".
  exit
fi
if [ -z "$5" ]
then
  echo "Missing parameter 'model'".
  exit
fi
if [ -z "$6" ]
then
  echo "Missing parameter 'free_mem'".
  exit
fi

exec_path=$1
scenario=$2
iterations=$3
max_nodes=$4
model=$5
free_mem=$6

python "$exec_path"/parallel_r.py -t "$iterations" -n "$max_nodes" -m "$free_mem" -l 20.0 -b ~/tmp/blacklist.txt -v ~/git/Winter-Track-Counts/inst/simulation/population_size.R notest "$scenario" "$model"

# ./population_size.sh ~/git/RParallelScreen/ E 1:50 60 SmoothModel-nbinomial-matern-ar1 


# ./population_size.sh ~/git/RParallelScreen/ E 1:50 60 FMPModel 20000

# ./population_size.sh ~/git/RParallelScreen/ A 1:50 60 FMPModel 0
# ./population_size.sh ~/git/RParallelScreen/ A 1:50 60 SmoothModel-nbinomial-ar1 0
# ./population_size.sh ~/git/RParallelScreen/ A 1:50 60 SmoothModel-nbinomial-matern-ar1 0

# ./population_size.sh ~/git/RParallelScreen/ Acombined 1:10 11 FMPModel
# ./population_size.sh ~/git/RParallelScreen/ Acombined 1:10 11 SmoothModel-nbinomial-ar1
# ./population_size.sh ~/git/RParallelScreen/ Acombined 1:10 11 SmoothModel-nbinomial-matern-ar1

# ./population_size.sh ~/git/RParallelScreen/ A10days 1:50 60 FMPModel
# ./population_size.sh ~/git/RParallelScreen/ A10days 1:50 60 SmoothModel-nbinomial-ar1
# ./population_size.sh ~/git/RParallelScreen/ A10days 1:50 60 SmoothModel-nbinomial-matern-ar1
