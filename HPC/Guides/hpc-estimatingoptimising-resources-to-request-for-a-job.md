---
title: Estimating/optimising resources to request for a job
date: 2026-09-08
---
(optimising-resources-to-request-for-a-job-heading-target)=

****We recommend starting with a small test dataset with which to test your script. This will allow you to examine the resources used by this test analysis and (hopefully) estimate what resources your full analysis will need. Of course, not all analyses are amenable to this process and may require further resource optimisation.****

:::{admonition} Prerequisites
:class: tip
You will need to be logged in to the HPC to run these commands \
You will need to have experience running simple PBS job scripts on the HPC \
You will need to have at least one Data Management Plan with an RPID
:::

(to-test-your-script-its-best-to-use-an-interactive-job)=
## To test your script its best to use an interactive job
If you copy and paste this command, remember to replace the `ABCDEF1234` parameter with the appropriate {abbr}`RPID (Research Project ID)` that you have access to:
```{code} bash
:linenos:
:emphasize-lines: 1
qsub -I -l select=1:ncpus=1:mem=16gb -l walltime=12:00:00 -P ABCDEF1234
```

By using an interactive job, you can test the various parts of your script in real-time. For example, trialling different versions of modules to see which are compatible with each other, or trialling different versions of packages that are compatible with each other when creating a new conda environment. See here for information about [conda environments](../../Learning_more/hpc-conda-package-and-environment-manager/hpc-conda-package-and-environment-manager.md/#why-use-conda) and [modules](../../Learning_more/hpc-accessing-available-software/hpc-accessing-available-software.md/#the-module-system).

You can setup the software required in this interactive job, and then test that the analysis script that you want to run, works with a small test input file, or with less iterations/steps.

Once you have figured out these types of setup steps, you can start building your batch job script:

```{image} attachments/New_job_example_100.jpg
:alt: Code block showing the different sections and what they do
:width: 900px
:align: center
```
***

(monitoring-the-resources-used-by-your-test-job)=
## Monitoring the resources used by your test job

```{code} bash
:linenos:
:emphasize-lines: 1
qstat -fx $PBS_JOBID
```

This command is a way to monitor your job when it is queueing, running, on hold, and recently finished (by adding the `x`). As these logs are not kept forever, only recently finished jobs can be accessed this way. Once a job has started running, the output of the command above (`qstat -fx $PBS_JOBID`) will show the `resources_used` for various parameters:

*   `resources_used.cpupercent` = % of CPUs used
    
*   `resources_used.cput` = CPU time
    
*   `resources_used.mem` = memory used in the job
    
*   `resources_used.ncpus` = this should match the ncpus in your job if it uses all of them
    
*   `resources_used.vmem` = virtual memory used
    
*   `resources_used.walltime` = walltime used for the job
    

One way to preserve this information is to save this information to a file, which you can do by adding this line to the end of your script:

```{code} bash
:linenos:
:emphasize-lines: 1
qstat -fx $PBS_JOBID > resource_usage_$PBS_JOBID
```

You can compare information about the resources used with information about what resources you requested, which will be in this same file. For example, the `qstat -fx $PBS_JOBID` command will also show these parameters:

*   `Resources_List.mem` = memory requested for the job 
    
*   `Resources_List.ncpus` = number of CPUs requested
    
*   `Resources_List.ngpus` = number of GPUs requested
    
*   `Resources_List.select` = select statement, which includes `select:` # chunks, `ncpus:` # CPUs, `ngpus:` # GPUs, `mem:` amount of memory, `cpu_id:` if you specified it, etc 
    
*   `Resources_List.walltime` = walltime requested

(walltime-as-a-resource)=
## Walltime as a resource

If you run out of walltime in your analysis, you won’t get an informative output/error file so you may not figure out where your analysis got up to. This is not helpful to judge how much to increase your walltime. So, if you add a `set -x` command early in your script, it will create an output of everything that went on in your script:

```{code} bash
:linenos:
:emphasize-lines: 1
set -x
```
(optimising-resources-requested-in-your-script)=
## Optimising resources requested in your script

When testing a new script, you may need to try a few different values for memory, ncpus, walltime etc. One way to do this is to write a shell script that will loop through different values for various parameters. A script is shown below with a simple ‘Hello World’ example. When you try this for your analysis, you’ll still want to do this test with a relatively small test dataset and observe the `resource_usage_${PBS_JOBID}` file for each job, which set of parameter values gave the most efficient use of the resources requested (sometimes increasing the number of CPUs or memory does not increase the actual speed of an analysis).

(general-jobs-ncpus-mem-etc)=
### General jobs: NCPUs, MEM, etc
If you copy and paste this script, remember to replace the `ABCDEF1234` parameter in line 25 with the appropriate {abbr}`RPID (Research Project ID)` that you have access to:
```{code} bash
:linenos:
:emphasize-lines: 3,4,5,7,8,9,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35
#!/bin/bash

ncpu_first=2
ncpu_final=16
ncpu_step=2

mem_first=2
mem_final=10
mem_step=2


for (( ncpu=$ncpu_first; ncpu<=$ncpu_final; ncpu+=$ncpu_step ));
	do
	for (( mem=$mem_first; mem<=$mem_final; mem+=$mem_step ));
		do
		# Test to make sure looping is correct
		echo $ncpu $mem
		# set a useful job name
		jobname="M_${ncpu}_${mem}"
		cat << EOF | qsub
#!/bin/bash -l
#PBS -N $jobname
#PBS -l select=1:ncpus=${ncpu}:mem=${mem}gb:cpu_id=any
#PBS -l walltime=01:00:00
#PBS -P ABCDEF1234
#PBS -j oe

cd \$PBS_O_WORKDIR

echo "Hello world: checking speed of script with ncpus=$ncpu and mem=${mem}gb"

qstat -fx \$PBS_JOBID > resource_usage_\$PBS_JOBID
EOF
	done
done

```

There are 2 loops in this script, one for the number of CPUs and the other for the amount of memory (in hundreds of MB). What this script does is input the different values of `ncpus` and `mem` that it feeds into a new PBS job script for each combination of variables that it then submits using `qsub`.

:::{important}
When using this type of script, be mindful of the total number of loops/job scripts you may be generating/submitting influences how the PBS scheduler prioritises your jobs (i.e. as it is easy to run huge numbers of jobs this way without realising, you may slow down the rate at which your jobs move through the queues). For example, this script has 8 loops for the `ncpus` values and 5 loops for the `mem` values, which means there will be 40 different jobs submitted. Note, this script does not include a PBS line to send an email for each job, or else you’ll get 40 emails.
:::

[Back to the top](#optimising-resources-to-request-for-a-job-heading-target)
***

(software-specific-methods-of-optimisation-nwchem)=
### Software-specific methods of optimisation: NWCHEM

There are ways to optimise scripts that might be specific to different pieces of software. With `NWCHEM`, assuming you have 64 cores, you can run 64 MPI processes and 1 OpenMP thread (i.e. 64x1), all the way up to 1x64 (1 MPI process and 64 OpenMP threads). You will find that NWChem does not scale to more than 8 threads per process, because of Amdahl’s Law, as well as the NUMA properties of some modern servers. However, you may find that 16x4 is better than 64x1, for example. This is particularly true when file I/O (i.e. file input/output, which is the process of transferring data to or from a storage medium like a file) is happening because Linux serializes this. The CCSD(T) semidirect module does nontrivial file I/O in some scenarios, so it benefits from OpenMP threading even if the compute efficiency is imperfect.

Below is a simple example of a script that could be useful for performing scaling MPI x OpenMP scaling studies, with a sample input file below it (remember to replace the `ABCDEF1234` parameter in line 5 with the appropriate {abbr}`RPID (Research Project ID)` that you have access to):

```{code} bash
:linenos:
:emphasize-lines: 1,2,3,4,5,6,7,9,11,12,13,15,17,20,24,25,26,27,30,33,37,38,39,40,41,42,46,49,50,51,52,53,54,57,58,59,61,63
#!/bin/bash -l
#PBS -N nwchem_benchmarking
#PBS -l select=1:ncpus=64:mem=8GB:cpu_id=any
#PBS -l walltime=05:00:00
#PBS -P ABCDEF1234
#PBS -j oe
#PBS -m abe

cd $PBS_O_WORKDIR

module load GCC/13.3.0
module load OpenMPI/5.0.3
module load NWChem/7.2.3

echo "This job's process 0 host is: " `hostname`; echo ""

prefix="nwchem_run1"

# total number of cores available
N=$NCPUS

# Set up NWCHEM environment, permanent, and scratch directory
# Do not delete/modify the following 4 lines.
export NWCHEM_ROOT="/mnt/weka/pkg/rhel94/AuthenticAMD-25/software/NWChem/7.2.3-foss-2024a"
export PERMANENT_DIR=$PBS_O_WORKDIR
export MY_SCRDIR=`whoami;date '+%m.%d.%y_%H:%M:%S'`
export MY_SCRDIR=`echo $MY_SCRDIR | sed -e 's; ;_;'`

#Edit following line to match your input file.
INPUT_FILE="input.nw"

# Edit following lines in order to adjust the optimal memory for your system (or alter from default memory breakup)
MEMORY_TTL=3686
#MEMORY_GLBL=2764

# Do not edit the following 7 lines
RUN_FILE="${prefix}.nw"
export SCRATCH_DIR=${PBS_O_WORKDIR}/${MY_SCRDIR}_$$
mkdir -p $SCRATCH_DIR
printf '%s\t%s\n' 'scratch_dir'   $SCRATCH_DIR >> temp
printf '%s\t%s\n' 'permanent_dir' $PBS_O_WORKDIR >> temp
printf '%s%s%s%s%s%s\n' 'memory ' 'total ' $MEMORY_TTL ' mb' >> temp
#printf '%s%s%s%s%s%s\n' 'memory ' 'total ' $MEMORY_TTL ' mb' ' global ' $MEMORY_GLBL ' mb' >> temp

# Do not remove/modify $RUN_FILE or $OUTPUT_FILE
cat ${INPUT_FILE} temp > ${RUN_FILE}

# Starts NWCHEM job. We do not expect NWChem to scale to more than 8 threads per process:
for P in $((N)) $((N/2)) $((N/4)) $((N/8)) ; do
  T=$((N/${P}))
  export OMP_NUM_THREADS=${T}
  OUTPUT_FILE="${prefix}_${T}threads_${P}mpi.out"
  mpirun -n $P nwchem ${RUN_FILE} > ${OUTPUT_FILE}
done

# Do  not remove following 3 lines - they clean up scratch and temporary files.
rm -r $SCRATCH_DIR
rm -r $RUN_FILE
rm temp

qstat -fx $PBS_JOBID > resource_usage_${PBS_JOBID}

echo 'Job is done!'
```

:::{caution}
Check this above - may need to make each P a new job to capture the resource usage and judge the best threads per process
:::

See the [NWCHEM page](../../Specific_software/biochemistry/biochemistry/how-to-use-software-nwchem.md) to learn more about the basics of the software.

[Back to the top](#optimising-resources-to-request-for-a-job-heading-target)
***
%(software-specific-methods-of-optimisation-abaqus)=
%### Software-specific methods of optimisation: ABAQUS

%You can download some example files to test the most efficient use of CPU resources and GPU resources via an interactive job:

%```{code} bash
%:linenos:
%:emphasize-lines: 1
%qsub -I -l select=1:ncpus=1:mem=16gb -l walltime=03:00:00
%```

%Then load the abaqus module and use the fetch command to download the example input files:

%```{code} bash
%:linenos:
%:emphasize-lines: 1,2
%module load abaqus/2022-hotfix-2223
%abaqus fetch job=exepxme1
%```

%This will download the exepxme1.inp input file to the folder you were in when you ran that command. So long as you copy that input file into the folder where you’re running your PBS batch job script, then it will run correctly.

%Below is a simple example of a script that could be useful for performing MPI x OpenMP scaling studies (i.e. hybrid parallel processing within nodes using thread-based parallelization and between nodes using MPI-based parallelization), with a sample input file and by specifying the number of `mpiprocs=#` and
%`mpirun -np #`, plus `OMP_NUM_THREADS`:

%```{code} bash
%:linenos:
%:emphasize-lines: 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34
%#!/bin/bash -l
%#PBS -N abaqus
%#PBS -l select=2:ncpus=16:mem=48GB:mpiprocs=2
%#PBS -l walltime=10:00:00
%#PBS -j oe
%#PBS -m abe
%
%# Change in directory.
%cd $PBS_O_WORKDIR
%
%# Load modules, always specify version number.
%module load abaqus/2022-hotfix-2223
%module load impi/2018.5.288-iccifort-2019.5.281
%
%############### Section to be altered ################
%# Change this line below to reflect the input file
%input="exepxme1"
%######################################################
%
%echo $mp_host_list
%
%# Construct Abaqus environment file.
%cat << EOF > abaqus_v6.env
%mp_rsh_command="/opt/pbs/bin/pbs_tmrsh -n -l %U %H %C"
%mp_mpi_implementation = IMPI
%mp_mpirun_path = {IMPI: "/opt/pbs/bin/mpiexec.hydra"}
%memory="$(qstat -f $PBS_JOBID | grep -oP 'Resource_List.mem = \K[^ ]+' | /pkg/hpc/scripts/pbs_mem_bytes) b"
%cpus = $NCPUS
%EOF
%
%export OMP_NUM_THREADS=${NCPUS}
%
%# Run Abaqus
%mpirun -np 2 abaqus job=${input} analysis input=${input}.inp
%```

%You can add `threads_per_mpi_process=a_number` if it is different to the number of CPUs returned in `cpus = $NCPUS`. If these are the same value, then you will get a warning so only use one. Note: the `cpus = $NCPUS` parameter is the number of CPUs per node not the number of CPUs in total.

%Adding a line with `information=environment` variable in the Abaqus environment file will output the current environment settings to the log file.

%The `scratch=$TMP_DIR` variable specifies the scratch directory where the temporary files are created. Using `$TMP_DIR` means that this folder is automatically deleted after the job has finished. Version 2023 has issues with this though, so often its just best to leave that out of the Abaqus environment file.

%The `mp_mode=mpi` or `mp_mode=threads` variable defines how the parallelization is being run (but if you’re using a hybrid parallelization method [i.e. with both of these mp_modes] don’t specify this).

%The `$mp_host_list` variable will output the number and name of the node(s) used in the analysis.

%The `memory="$(qstat -f $PBS_JOBID | grep -oP 'Resource_List.mem = \K[^ ]+' | /pkg/hpc/scripts/pbs_mem_bytes) b"` variable is the maximum amount of memory or maximum percentage of the physical memory that can be allocated during the input file preprocessing and during the Abaqus/Standard analysis phase. For parallel execution on computer clusters, this memory limit specifies the maximum amount of memory that can be allocated to each process.

%***
%[Back to the top](#optimising-resources-to-request-for-a-job-heading-target)
%***
%:::{admonition} Resources used to write this page
%:class: hint
%*   [https://nwchemgit.github.io/Home.html](https://nwchemgit.github.io/Home.html)
%*   [https://www.nwchem-sw.org/index-php/Release61\_TCE.html](https://www.nwchem-sw.org/index-php/Release61_TCE.html)
%*   [https://hpcadvisorycouncil.atlassian.net/wiki/spaces/HPCWORKS/pages/2799534081/Getting+Started+with+NWChem+for+ISC22+SCC#:~:text=You will find that NWChem,happening, because Linux serializes this.](https://hpcadvisorycouncil.atlassian.net/wiki/spaces/HPCWORKS/pages/2799534081/Getting+Started+with+NWChem+for+ISC22+SCC#:~:text=You%20will%20find%20that%20NWChem,happening%2C%20because%20Linux%20serializes%20this.)
%*   [Valiev et al. (2010) Nwchem: A comprehensive and scalable open-source solution for large scale molecular simulations. Computer Physics Communications, 181(9):1477–1489.]

***
[Back to the top](#optimising-resources-to-request-for-a-job-heading-target)

* * *

**For further help contact eResearch** \
Submit a ticket: [http://qut.to/eresearch-support](http://qut.to/eresearch-support) \
Email us: eresearch@qut.edu.au \
Call us: 07 3138 8899