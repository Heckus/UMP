---
title: Submitting jobs on Aqua
date: 2026-09-08
---
(submitting-jobs-on-aqua-heading-target)=

****Jobs are submitted to the head node (i.e. aqua) after logging on, either via PBS job scripts or interactive jobs. In both cases, the job is submitted to a queueing system (PBS Pro) that takes into account the resources requested and the historical usage of the submitter (i.e. if you haven’t used the HPC much, your job will be ahead of someone that uses the HPC a lot).****

:::{admonition} Prerequisites
:class: tip
You will need to be logged in to the HPC to do these activities \
You will need to have at least one Data Management Plan with an RPID
:::

****There are two ways of running jobs on the HPC:**** \
****1. Interactive jobs: used to develop your batch job scripts (maximum time limit of 12hrs);**** \
****2. Batch jobs: the major way you will run your analyses (maximum time limit of 48hrs).**** 

In addition to aligning with NCI, the maximum 48 hour-wall time is proposed to enable more efficient scheduling of jobs, quicker fixes when issues occur and more frequent maintenance, resulting in a more stable system. User data has also revealed that a majority of jobs run on the HPC require less than 48 hours to complete.

There may be exceptions to the 48-hour wall time and the eResearch team will support users throughout the process. The team understands that there are jobs with long run times, and we are working through ways to support these jobs, for example [checkpointing](../Checkpointing/checkpointing.md). Checkpointing means that you frequently save the job state so your code can be requeued and resume computation from the last checkpoint, in case of a crash or reaching maximum wall time. 

***
(interactive-jobs)=
# Interactive jobs
Interactive jobs are submitted to the {abbr}`PBS queuing system (the scheduler that manages the queue of jobs submitted to Aqua)`, and you will have to wait for a node to become free just like a batch job. Walltime for all interactive jobs are limited to 12 hours and the maximum `ncpus`, `ngpus` and `mem` resources that can be requested are limited to maximise availability. 

(cpu-only-interactive-jobs)=
## CPU-Only Interactive Jobs
You can request an interactive CPU-only session using the following command (remember to replace the `ABCDEF1234` parameter with the appropriate {abbr}`RPID (Research Project ID)` that you have access to):
```{code} bash
:linenos:
:emphasize-lines:1
qsub -I -l select=1:ncpus=1:mem=4GB -l walltime=12:00:00 -P ABCDEF1234
```
The terminal will respond with a job number and then appear to 'hang'.

Once a node has been allocated it will drop you into a terminal prompt and you can type commands as usual, except these commands will be run inside the job.

For CPU-only interactive jobs, a user may request up to 8 Cores and 32 GB of memory in any configuration for a single job, and have up to 8 Cores and 32 GB of memory of resources running concurrently (remember, the max walltime for interactive jobs is 12 hours).
For example you may run 8 interactive jobs with `select=1:ncpus=1:mem=4gb` or a single job with `select=1:ncpus=8:mem=32g` or `select=8:ncpus=1:mem=4gb` or any configuration up to 8 Cores and 32 GB.

:::{note}
Do not use `-l place=scatter` if you request multiple chunks with `select`>1, as the `cpu_inter_exec` queue is only on one node so if you do force PBS to scatter your chunks across multiple nodes your job will never run. 
:::

(cpu-and-gpu-interactive-jobs)=
## CPU and GPU Interactive Jobs
To maximise utilisation and availability of GPUs, interactive CPU+GPU interactive sessions utilise Nvidia's Multi Instance GPU (MIG) technology. 
A `ngpus=1` resource in the GPU interactive queue is equivilant to a [MIG 1g.10gb profile](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/index.html#id15). Remember to replace the `ABCDEF1234` parameter with the appropriate {abbr}`RPID (Research Project ID)` that you have access to.

```{code} bash
:linenos:
:emphasize-lines:1
qsub -I -l select=1:ncpus=6:ngpus=1:mem=34gb -l walltime=12:00:00 -P ABCDEF1234
```
A user may request up to 12 CPUs and 64 GB of (`system`) memory with a max walltime for interactive jobs of 12 hours, and a maximum of 2 MIG GPUs in total but only 1 MIG GPU per interactive job. For example you may run 2 interactive jobs with `select=1:ncpus=6:ngpus=1:mem=32gb` or a single job with `select=1:ncpus=12:ngpus=1:mem=64gb` but you can't use `ngpus=2` as jobs CAN NOT be spread across multiple MIGs without specialised code (contact eResearch for help if you need to do this). 

(mpi-interactive-jobs-on-aqua)=
## MPI Interactive Jobs on Aqua
A multi-node (MPI) CPU interactive job could be created with this command (remember to replace the `ABCDEF1234` parameter with the appropriate {abbr}`RPID (Research Project ID)` that you have access to):
```{code} bash
:linenos:
:emphasize-lines: 1
qsub -I -l select=8:ncpus=1:mem=4GB:mpiprocs=8:cpu_id=AMD-25-17 -l walltime=10:00:00 -P ABCDEF1234
```
This MPI job has a total of 8 CPUs and 32GB of memory (as the `select` number multiplies by the `ncpus` and `mem` numbers). You will need to use the `cpu_id=<specific_type>` to ensure that all nodes are compatible with each other.

:::{note}
Do not use `-l place=scatter` if you request multiple chunks with `select`>1, as the `cpu_inter_exec` queue is only on one node so if you do force PBS to scatter your chunks across multiple nodes your job will never run. 
:::

## Exiting Interactive jobs
To finish any of these interactive jobs, type:

```{code} bash
:linenos:
:emphasize-lines: 1
exit
```

***
(batch-job-scripts)=
# Batch job scripts
Batch job scripts are written in the bash scripting language. In BASH, any line beginning with a `#` is a comment. A comment allows the person writing the script to make a human-readable note that is ignored when the script runs the commands within it. There are special instances of the `#` though. The first line in the example script below is one, it is called the `shebang`. The `#` at the beginning of lines 2-7 are also special instances of the `#` in action, where the `#` is utilised in PBS scripts through the special comment `#PBS`, which is called a PBS directive. PBS is the scheduler that manages the queue of jobs submitted to Aqua. All PBS directives are gathered together at the start of the script.

(an-example-pbs-script)=
## An example simple PBS script

You can save this as `example.aqua`, but remember to change the `<$USER@EMAIL.ADDRESS>` to your own email address. Also remember to replace the `ABCDEF1234` parameter in line 5 with the appropriate {abbr}`RPID (Research Project ID)` that you have access to:

```{code} bash
:linenos:
:emphasize-lines: 1,3,4,5,10
#!/bin/bash -l
#PBS -N example
#PBS -l select=1:ncpus=1:mem=8G:cpu_id=any
#PBS -l walltime=1:00:00
#PBS -P ABCDEF1234
#PBS -m abe
#PBS -M $USER@EMAIL.ADDRESS
#PBS -j oe

cd $PBS_O_WORKDIR
pwd
echo "hello world" 
```

The script above will simply print the working directory `pwd` and the string `"hello world"` to the standard output and terminate. The statement `echo "hello world"` can be replaced by anything that will run on the Linux command line.

(submitting-this-example-job-script)=
## Submitting this example job script
To submit this `example.aqua` job to the PBS scheduler on the HPC, you would follow these general guidelines:
1. Log into the HPC
[(instructions here)](./hpc-getting-started-with-high-performance-computing.md/#how-you-log-into-aqua-depends-on-the-operating-system-of-your-computer)
2. Copy the script `example.aqua` to the HPC
[(instructions here)](../Learning_more/hpc-transferring-files-tofrom-hpc/hpc-transferring-files-tofrom-hpc.md/#using-file-explorer-or-finder-to-mount-or-map-a-drive-to-the-hpc)
3. Submit the job using the `qsub` command:
```{code} bash
:linenos:
:emphasize-lines:1
qsub example.aqua
```

:::{warning}
If you created your job script on Windows and uploaded it to Aqua, ensure that it is converted to Unix format before attempting to use it (i.e. with the `dos2unix` script).
See the [Troubleshooting page](../Troubleshooting/hpc-faq-2-weird-errors.md/#bad-interpreter) for instructions on how to do this.
:::

***
(here-is-an-explanation-of-each-line-in-the-example-script)=
### Here is an explanation of each line in the example script

**Line 1 - [Shebang](https://en.wikipedia.org/wiki/Shebang_(Unix))**
```{code} bash
:linenos:
:emphasize-lines: 1
#!/bin/bash -l
```
This line (sometimes called [shebang](https://en.wikipedia.org/wiki/Shebang_(Unix)) for `#!`) sets the interpreter to `BASH` and the `-l` makes `BASH` act as if it had been invoked as a login shell. This is important as it results in the `modules` path being set correctly.

**Line 2 - Name of the job**
```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -N example
```

This line specifies the name of the job as `example`. This will appear in the console output when querying the job. Although jobs are allocated job-numbers, the name given here is a useful way to distinguish one job from another.

**Line 3 - Resource request**
```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -l select=1:ncpus=1:mem=8G:cpu_id=any
```

This line requests one CPU and 8GB of RAM (i.e. memory) on 1 node (on any CPU type) to run this job. For large jobs using software that can take advantage of multiple cores, you can increase the number of CPUs (while being mindful of other users and if you are sure your analysis can make use of > 1 CPU). This means the total number of CPUs is 1 x 1 = 1 CPUs, and the amount of memory would be 1 x 8 = 8GB of RAM.

**Line 4 - Walltime request**
```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -l walltime=1:00:00
```
This line requests 1 hour of CPU time (hr:min:sec). For larger and more complex computations, this number may be increased up to 48 hours. When selecting wall time it is recommended that you choose more than required. HPC support is unable to extend the wall time for submitted jobs, as this causes issues to the fair share workings of the cluster.

```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -l walltime=48:00:00
```
Wall time is the amount of time that passes for a hypothetical clock on the wall while the job is actually running. It is distinct from the amount of CPU time, which for a multiple CPU job will be many times this value. 

:::{important}
There is a maximum walltime on all batch jobs of 48hrs.

In addition to aligning with NCI, the 48 hour-wall time is proposed to enable more efficient scheduling of jobs, quicker fixes when issues occur and more frequent maintenance, resulting in a more stable system. User data has also revealed that a majority of jobs run on the HPC require less than 48 hours to complete.

There may be exceptions to the 48-hour wall time and the eResearch team can support users to figure out what works best for each job. The team understands that there are jobs with long run times, and we are working through ways to support these jobs, for example checkpointing. Checkpointing means that you frequently save the job state so your code can be requeued and resume computation from the last checkpoint, in case of a crash or reaching maximum wall time: [see the Checkpointing page](../Checkpointing/checkpointing.md/#introduction-to-checkpointing-heading-target).
:::

:::{warning}
Be careful of the time to the next scheduled maintenance when requesting large wall times. If your requested wall time is longer than the time until the next scheduled maintenance, it won’t run and will sit in the queue until after the maintenance period is over. You can see the number of hours until the next scheduled maintenance when you log in to Aqua, as its part of the standard message that pops up.
:::

**Line 5 - Specifying your RPID**
```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -P ABCDEF1234
```

This line specifies the `Research Project ID` (RPID), i.e. the project, that your analysis belongs to. It became a `mandatory parameter from 2nd November 2026`, to help strengthen the connection between research projects and the computing resources used to support them, improving visibility, governance and the management of research infrastructure. In this example, we use `ABCDEF1234` but you will need to use one of the `RPID`s that you belong to.

**Line 6 - Email me about job**
```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -m abe
```

This line requests an email to be sent to the user when the job aborts (a), begins (b), and ends (e). These emails are sent to your default email on record (i.e. `<username>@qut.edu.au` or `<username>@hdr.qut.edu.au`).

**Line 7 - Alternate email address**
```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -M $USER@EMAIL.ADDRESS
```

This line tells the PBS system to send any emails to an alternate email address than your default email on record associated with the username you logged into the HPC with (i.e. if you have both an HDR and staff email address, but logged in as your student username, then you can specify your staff email address be used for emails about this job). \
**DO NOT USE THIS LINE AS IT IS HERE, AS THIS WILL NOT REACH YOUR EMAIL ADDRESS. YOU NEED TO CHANGE THE `<$USER@EMAIL.ADDRESS>` TO YOUR OWN EMAIL ADDRESS.**

**Line 8 - Standard output and error files**
```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -j oe
```

Your job automatically creates 2 files, one with anything that would normally be output to the screen (as the [`stdout`](../Miscellaneous/hpc-appendix-what-do-these-terms-mean.md/#standard-output) file), and the other with any errors (as the [`stderr`](../Miscellaneous/hpc-appendix-what-do-these-terms-mean.md/#standard-error) file). The output file is usually named something like this: `job_name.o12234567` and the error file is usually named something like this: `job_name.e12234567`. This line requests to merge the output and error files into one file. Both streams will be merged, and intermixed, as standard output: `job_name.o12234567`.

**Line 9 - Changing directory**
```{code} bash
:linenos:
:emphasize-lines: 1
cd $PBS_O_WORKDIR
```

This line changes to the directory from which you submitted the job (i.e. when you used `qsub` command). This allows you to easily load any required input files, and save any output files into the correct folder. 

**Line 10 - Print the working directory**
```{code} bash
:linenos:
:emphasize-lines: 1
pwd
```

This line prints the working directory to the screen (or in this case standard output).

**Line 11 - Running a simple command**
```{code} bash
:linenos:
:emphasize-lines: 1
echo "hello world"
```

This line echoes the line `hello world` to the screen (or in this case standard output).


Once you have written your job script, preferably on Aqua using a text editor such as nano, it may be submitted via the `qsub` command.

```{warning}
If you created your batch job script on a Windows host and then copied it to the HPC, you will need to change the format of the line endings in your job script from the Windows standard (CRLF) to the Unix standard (LF).
See the [Troubleshooting page](../Troubleshooting/hpc-faq-2-weird-errors.md/#bad-interpreter) for instructions on how to do this.
```


***
# Using MPI in batch jobs
When running simulations with a single node, we call this a **serial run**. It is recommended to try to make optimizations for how fast your serial run is before you jump into a parallel programming model (for example `MPI`). 

If you need parallelization because you are running out of memory but not computational power, e.g. you have a simulation and the problem size is so large that your data does not fit into the memory of a single node anymore, then MPI is a potential solution. 

In this case, you probably want to start one MPI process on each node, thereby making maximum use of the available memory while limiting communication to the bare minimum (i.e. number of nodes is equal to the number of MPI processes). However, not all software can make use of MPI, so check this before attempting to use MPI in your job.

If you are sure that the software in your script can make use of multiple nodes/chunks (and you understand how MPI works), then you can request >1 node/chunk, as per the line below:
see here for more information about [Parallelising your analyses (MPI vs OpenMP)](../Speeding_up/hpc-parallelising-your-analyses-mpi-vs-openmp/hpc-parallelising-your-analyses-mpi-vs-openmp.md/#parallelising-your-analysis-heading-target)

```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -l select=2:ncpus=1:mem=32gb:cpu_id=any
```

The line above will request 1 CPUs spread across 2 nodes with a total of 64GB of memory.

:::{important}
Remember, every resource is multiplied by the number of nodes/chunks you request.
:::

(allocating-processes-to-nodes-or-chunks)=
## Allocating processes to nodes or chunks

When you request > 1 node/chunk (using the select variable), you can specify how your nodes/chunks are allocated using the place statement. For example, you can specify if your chunks are willing to share a vnode or host with other chunks.

This line will tell PBS to scatter your chunks on different hosts, i.e. if you’re using MPI processes (multithreading) only one chunk is taken from a specific host:

```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -l place=scatter
```

However, this line will tell PBS to allocate all your chunks to one host:

```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -l place=pack
```

:::{note} MPI across chunks/nodes can not be combined with checkpointing
One way around that is to force all your `select=#` chunks to be packed on to one node with the `#PBS -l place=pack` line. Otherwise, you may have to choose whether `parallelisation` or extended `walltime` is more important for your analysis.
:::

Sometimes, certain software is written to work on specific CPU/GPU types, or runs better if all the threads are running on the same type of hardware (e.g. MPI jobs need to run on the same type of hardware). So, if you want to request that your threads are only allocated to the same type of CPU, then you can specify it in either of 2 ways:
1. Use `place=group=cpu_id` if you aren't specifying the `cpu_id` type (i.e. defaults to `any`). Remember to replace the `ABCDEF1234` parameter in line 5 with the appropriate {abbr}`RPID (Research Project ID)` that you have access to:
```{code} bash
:linenos:
:emphasize-lines: 3,4
#!/bin/bash -l
#PBS -N TEST
#PBS -l select=4:ncpus=2:mem=8GB:cpu_id=any:mpiprocs=2
#PBS -l place=group=cpu_id
#PBS -P ABCDEF1234
#PBS -l walltime=4:00:00
#PBS -j oe
#PBS -m abe
```

****OR**** 

2. Specify `cpu_id` so it uses all the same CPU type (remember to replace the `ABCDEF1234` parameter in line 5 with the appropriate {abbr}`RPID (Research Project ID)` that you have access to):
```{code} bash
:linenos:
:emphasize-lines: 3
#!/bin/bash -l
#PBS -N TEST
#PBS -l select=4:ncpus=2:mem=8GB:cpu_id=AMD-25-17:mpiprocs=2
#PBS -l walltime=4:00:00
#PBS -P ABCDEF1234
#PBS -j oe
#PBS -m abe
```

:::{attention}
For large jobs using software that can take advantage of multiple cores, it is easier to find 24 separate instances of 1 CPU than 24 CPUs all together on one node/chunk. So, this means that your job will spend less time in the queue if you request: \
`#PBS -l select=24:ncpus=1` rather than `#PBS -l select=1:ncpus=24`.
:::

(using-gpus-in-a-batch-job)=
# Using GPUs in a batch job
GPU batch jobs run on the whole of a GPU (i.e. not MIGs), so multiple GPUs (on one node) can be requested within a batch job, for example using `ngpus=2` (remember to replace the `ABCDEF1234` parameter in line 5 with the appropriate {abbr}`RPID (Research Project ID)` that you have access to):
```{code} bash
:linenos:
:emphasize-lines: 3
#!/bin/bash -l
#PBS -N TEST
#PBS -l select=1:ncpus=4:ngpus=2:mem=64GB:gpu_id=H100
#PBS -l walltime=1:00:00
#PBS -P ABCDEF1234
#PBS -j oe
#PBS -m abe
```

The only types of `gpu_id` that currently work are `H100` and `A100`. The line above will request 4 CPU cores and 2 GPU cores on 1 H100 node/chunk with 64GB of memory in total.

(using-gpus-on-multiple-nodes)=
# Using GPUs on multiple nodes
We are working on a `CUDA-aware MPI` so that jobs can run on multiple GPU nodes with the appropriate communication between the nodes. This is an ongoing piece of work so we will update here once it has been successfully implemented.

(more-info-about-hardware-types)=
# More info about Hardware types
To find out what types of CPUs, GPUs, etc we have (and also which ones are busy), try typing this line on the HPC:

```{code} bash
:linenos:
:emphasize-lines: 1
pbsnodeinfo
```

The `cpu_id` and `gpu_id` values are dynamically generated from system hardware utilities: 

* For `cpu_id` the format is `<Vendor ID short name>-<CPU Family>-<Model>`
* For `gpu_id` the format is `<Model ShortName>`.

For example, AMD EPYC 9684X `cpu_id` is `AMD-25-17` derived from the `lscpu` command output.

```{code} bash
[aquarius01 ~]$ lscpu | head
Architecture:                       x86_64
CPU op-mode(s):                     32-bit, 64-bit
Address sizes:                      52 bits physical, 57 bits virtual
Byte Order:                         Little Endian
CPU(s):                             48
On-line CPU(s) list:                0-47
Vendor ID:                          AuthenticAMD
Model name:                         AMD EPYC 9274F 24-Core Processor
CPU family:                         25
Model:                              17
```
 
By default CPU only jobs will be set to `cpu_id=any`. To target a specific CPU type you will need to specify the `cpu_id` in your resource request ([see About Aqua page for the CPU specs](../Major_changes/about_aqua.md/#summary-of-cpu-hardware)).

By default GPU jobs will be set to `gpu_id=any`, and if you want to target a specific GPU type you will also need to specify the `gpu_id` in your resource request ([see About Aqua page for the GPU specs](../Major_changes/about_aqua.md/#summary-of-gpu-hardware)).

Non-MPI jobs that require up to 6TB will be automatically scheduled on the large node if memory larger than 1.5TB is requested.

(array-jobs)=
# Array jobs

A job array is a container for a collection of similar jobs submitted under a single job ID. It can be submitted, queried, modified, and displayed as a unit. The jobs in the collection are called sub-jobs. Although in theory there is almost an unlimited number of sub-jobs you could submit as a job array, because the QUT HPC has user limits it is best to limit the sub-jobs to a maximum of 5000.

All subjobs in one job array have the same attributes, including resource requirements and limits. This means that if you set the memory of the job for 128GB, then each sub-job will have 128GB too.

Job arrays are submitted through the use of the `-J` option to `qsub` for an interactive job, or by using `#PBS -J` in your PBS batch job script:

```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -J 0-3
```
The `$PBS_ARRAY_ID` variable refers to the array job. The `$PBS_ARRAY_INDEX` variable refers to the individual sub-job within the array job (by default numbered starting from “0”). So when you come to write the line in the PBS batch job script where you are specifying the command to run, you will use these variables to refer to input files, output files etc.

```{code} bash
:linenos:
:emphasize-lines: 1
matlab -nodisplay -nosplash matlabdemo${PBS_ARRAY_INDEX}.m > out.dat${PBS_ARRAY_INDEX}
```

This means that four individual jobs will be running (sub-jobs 0-3, but each will be subject to the queueing system), and the array parent job will appear with \[square brackets\] when you check using `qstat -u $USER` (i.e. 5551111\[\].pbs).

When you check the state of the array parent job using `qstat -fw 5551111[].aqua` you can see towards the end of the output something like:
```{code} bash
:linenos:
:emphasize-lines: 1
array_state_count = Queued:1 Running:2 Exiting:0 Expired:1
```

which tells you how many of the sub-jobs are queued, running, finishing, finished etc.

## Limiting concurrently running array sub-jobs
If you want to limit how many array sub-jobs are being run at once, there is a way to do this (i.e. if there are a limited number of licences for the software you're using). For example, if you have 1000 similar jobs to be run but you only want 20 to be running concurrently, use this command:

```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -J 1-1000%20
```

(dependencies)=
# Dependencies

PBS allows you to specify dependencies between two or more jobs. Dependencies are useful for a variety of tasks, such as:

*   Specifying the order in which jobs in a set should execute
    
*   Requesting a job run only if an error occurs in another job
    
*   Holding jobs until a particular job starts or completes execution
    

There is no limit on the number of dependencies per job. Use this option to define dependencies between jobs:

```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -W depend=<dependency list>
```

where `<dependency list>` has the format `<type>:<arg list>[,<type>:<arg list>...]`, where except for the `on` type, the arg list is one or more PBS job IDs in the form `<job ID>[:<job ID>...]`

These are the available dependency types:

*   `after:<arg list>` this job may start only after all jobs in `<arg list>` have started execution.
    
*   `afterok:<arg list>` this job may start only after all jobs in `<arg list>` have terminated with no errors.
    
*   `afternotok:<arg list>` this job may start only after all jobs in `<arg list>` have terminated with errors.
    
*   `afterany:<arg list>` this job may start after all jobs in `<arg list>` have finished execution, with or without errors. This job will not run if a job in the `<arg list>` was deleted without ever having been run.
    
*   `before:<arg list>` jobs in `<arg list>` may start only after specified jobs have begun execution. You must submit jobs that will run before other jobs with a type of `on`.
    
*   `beforeok:<arg list>` jobs in `<arg list>` may start only after this job terminates without errors.
    
*   `beforenotok:<arg list>` if this job terminates execution with errors, the jobs in `<arg list>` may begin.
    
*   `beforeany:<arg list>` jobs in `<arg list>` may start only after specified jobs terminate execution, with or without errors. Requires use of `on` dependency for jobs that will run before other jobs.
    

*   `on:count` this job may start only after `count` dependencies on other jobs have been satisfied. This type is used in conjunction with one of the `before` types. `count` is an integer greater than `0`.
    
*   `runone:<job ID>` puts the current job and the job with `job ID` in a set of jobs out of which PBS will eventually run just one. To add a job to a set, specify the `job ID` of another job already in the set.
    

For example, the job with this specification will only run after the job `1234567.aqua` has terminated with no errors:

```{code} bash
:linenos:
:emphasize-lines: 1
#PBS -W depend=afterok:1234567.aqua
```
(other-important-information)=
# Other important information
(allocation-of-jobs-to-nodes)=
## Allocation of jobs to nodes

Jobs are allocated to suitable machines or split across several machines. For example, if a job requires 8 CPUs these may be allocated on 8 separate nodes, or on one node. Every few minutes the list is reassessed. This produces a delay between batches of jobs submitted by one user, each batch being allocated machines in separate passes through the list several minutes apart.

(held-jobs)=
## Held jobs

If a job fails repeatedly or if the resources requested cannot be fulfilled the job will be HELD, that is, scheduled never to run. Jobs with system holds of this type must be released by eResearch staff, so just submit a request here: [http://qut.to/eresearch-support](http://qut.to/eresearch-support).

(job-progress)=
## Job Progress

### qstat
Progress of your job `<PBS_JOBID>` can be checked via:

```{code} bash
:linenos:
:emphasize-lines: 1
qstat <PBS_JOBID>
```

Or you can check on all your jobs using the `$USER` environment variable:

```{code} bash
:linenos:
:emphasize-lines: 1
qstat -u $USER
```

When you want to find out all the information about your job: the resources its actually using, what node its running on, whether it failed or finished OK etc, then you can get a full description via:

```{code} bash
:linenos:
:emphasize-lines: 1
qstat -fx <PBS_JOBID>
```
The `-f` gives the full description, and the `-x` shows jobs that have finished as well as current jobs.

***
### qpeek
If you want to monitor what is being written to your standard output (i.e. [`stdout`](../Miscellaneous/hpc-appendix-what-do-these-terms-mean.md/#standard-output)) or standard error (i.e. [`stderr`](../Miscellaneous/hpc-appendix-what-do-these-terms-mean.md/#standard-error)) files, while the job is still running you can use this command to show you the most recent 10 lines written to the `stdout` file (at the time you run the command):
```{code} bash
:linenos:
:emphasize-lines: 1
qpeek -o <PBS_JOBID>
```
AND this command to show you the most recent 10 lines written to the `stderr` file (at the time you run the command):
```{code} bash
:linenos:
:emphasize-lines: 1
qpeek -e <PBS_JOBID>
```

If you add the `-f` option to the `qpeek` command you will see a live version of the file with new lines being added as it happens:
```{code} bash
:linenos:
:emphasize-lines: 1
qpeek -f -e <PBS_JOBID>
```

(killing-a-job)=
## Killing a job

### qdel
If you need to delete a queued or running job, for example if you realised that you didn't request enough memory and want to change it, you can use the **qdel** command:

```{code} bash
:linenos:
:emphasize-lines: 1
qdel {jobid}
```
***
[Back to the top](#submitting-jobs-on-aqua-heading-target)
+++
***
:::{admonition} Resources used to write this page
:class: hint
*   [https://help.altair.com/2022.1.0/PBS Professional/PBSReferenceGuide2022.1.pdf](https://help.altair.com/2022.1.0/PBS%20Professional/PBSReferenceGuide2022.1.pdf)
:::
* * *

**For further help contact eResearch** \
Submit a ticket: [http://qut.to/eresearch-support](http://qut.to/eresearch-support) \
Email us: eresearch@qut.edu.au \
Call us: 07 3138 8899
