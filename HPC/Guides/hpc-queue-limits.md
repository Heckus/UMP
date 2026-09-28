---
title: Queues and limits
date: 2025-09-24
---
(queue-limits-heading-target)=

## Execution Queues

An execution queue is the home for waiting and running jobs. A job must reside in an execution queue to be eligible to run. The PBS scheduler will automatically place your job on an execution queue based on the requested resources.

| Name           | Interactive | Description                        |
| -------------- | ----------- | ---------------------------------- |
| cpu_batch_exec | False       | CPU batch execution queue          |
| cpu_inter_exec | True        | CPU interactive execution queue    |
| gpu_batch_exec | False       | GPU batch execution queue          |
| gpu_inter_exec | True        | GPU interactive execution queue    |
| cpu_batch_exlm | False       | Large memory batch execution queue |

### User Limits
There is a limit on the total number of jobs each user can have running and queued concurrently. The maximum number of queued jobs per user is `10000` and the maximum number of running jobs per user is `3382`.

### Job Limits

Below are the resource limits for a single job in the available execution queues.

If a job exceeds the resources of a single node (see command `pbsnodeinfo` below for [instructions on how to find out max resources of individual nodes](#pbsnodeinfo-queue-limits)), it must be configured to run across multiple nodes with tools such as [MPI](../../Speeding_up/hpc-parallelising-your-analyses-mpi-vs-openmp/hpc-parallelising-your-analyses-mpi-vs-openmp.md/#how-to-tell-which-method-of-multithreading-to-use).

|                | Walltime | Walltime | Memory  | Memory  | CPU     | CPU     | GPU     | GPU     |
| :------------- | :------: | :------: | :-----: | :-----: | :-----: | :-----: | :-----: | :-----: |
| **Queue**      | **Min**  | **Max**  | **Min** | **Max** | **Min** | **Max** | **Min** | **Max** |
| cpu_batch_exec | 00:10:00 | 48:00:00 | 1GB     | 16384GB | 1       | 2048    | 0       | 0       |
| cpu_inter_exec | 00:10:00 | 12:00:00 | 1GB     | 34GB    | 1       | 8       | 0       | 0       |
| gpu_batch_exec | 00:10:00 | 48:00:00 | 1GB     | 1920GB  | 1       | 256     | 1       | 8       |
| gpu_inter_exec | 00:10:00 | 12:00:00 | 1GB     | 68GB    | 1       | 12      | 1       | 2       |
| cpu_batch_exlm | 00:10:00 | 48:00:00 | 1479GB  | 6015GB  | 1       | 180     | 0       | 0       |
*Walltime is shown as hr:min:sec.*

:::{note} Example explaining `Large Memory Node (cpu_batch_exlm)` vs. `CPU batch` job limits
*If you have a large memory requirement for your job you may wish to target the `Large Memory Node (cpu_batch_exlm)` as it is specifically set aside for large memory jobs. To ensure your job will run on this node, you could request `select=1` and `mem=4200GB` (or `select=2` and `mem=2100GB` etc) as then your job will be routed to the `cpu_batch_exlm` queue because your total memory (`4200GB`) fits within that node's job limits. If you request too much total memory though, your job will be sent to the normal `cpu_batch_exec` queue, where it will need to be run across multiple chunks/nodes with [MPI](../../Speeding_up/hpc-parallelising-your-analyses-mpi-vs-openmp/hpc-parallelising-your-analyses-mpi-vs-openmp.md/#how-to-tell-which-method-of-multithreading-to-use) to ensure the processes run on different nodes can communicate with each other. For example, if you request `select=5` and `mem=1260GB` (or `select=6` and `mem=1020GB` etc) then your job will be routed to the `cpu_batch_exec` queue because your total memory requested is > `6015GB`, but if your analysis is not capable of using `MPI` then it will only be able to run processes on one of those chunks/nodes and will waste the rest of the resources you requested.*
:::

### Queue Limits

In addition to individual job limits, limits are applied to each queue. Queue limits apply to the total requested resources for all running jobs of a `user`.

| Queue          | Running Jobs | Job launches/min | Memory  |  CPU | GPU |
| :------------- | :----------: | :--------------: | :-----: | :--: | :-: |
| cpu_batch_exec | 3072         | 60               | 24576GB | 3072 | 0   |
| cpu_inter_exec | 8            | 60               | 34GB    | 8    | 0   |
| gpu_batch_exec | 24           | 60               | 7680GB  | 1024 | 24  |
| gpu_inter_exec | 2            | 60               | 68GB    | 12   | 2   |
| cpu_batch_exlm | 4            | 60               | 6015GB  | 180  | 0   |

:::{note} Example explaining `Job launches/minute` (i.e. `rate limit`) characteristic of queue limits
*If you have `3071` jobs currently running in the `cpu_batch_exec` queue (remember the max. is just 1 job more at `3072`) and you submit another `200` jobs to the same queue, all `200` of those new jobs will go into that queue to wait for room to run on the HPC. If there is room on the HPC to run some of your 200 jobs, it will only start running `job 1 of those 200` in the next cycle of the PBS scheduler, which runs approximately every minute (i.e. taking you up to the maximum of `3072 currently running jobs` in that queue). If `100` of your currently running jobs finish (reducing your total running job number to `2972`), then `60 of the rest of your 199 queued jobs` will start in the next cycle of the PBS scheduler (i.e. approx. 1 minute later, remember there is a max. of `60` job launches per minute/cycle), and the next `40` will wait for the subsequent cycle of the PBS scheduler (i.e. 2 minutes later, taking it back up to the max. of `3072` running jobs again). Any of your further `99` queued jobs will have to wait until more of your currently running jobs finish in order to run.* 

*Also, remember that the max. number of CPUs is `3072` and the max. memory is `24,576GB` for the `cpu_batch_exec` queue, so the max. number of running jobs is only the limiting factor to your running `cpu_batch_exec` jobs if these jobs request `ncpus=1` and the memory averages out to be `mem=8GB` per job for these `3072` jobs, otherwise the max. CPUs or the max. memory will be the limiting factor. Once one of these jobs request `> 1CPU` or the total memory exceeds `24,576GB`, your maximum number of running jobs will drop below `3072` to account for the larger job resource requests.*

**Ultimately, the factor limiting the number of your currently running jobs in a specific queue is whichever of these 3 maximums is reached first: total number of running jobs, total number of CPUs and total amount of memory for that specific queue.**
:::

## Queue Commands

:::{admonition} Prerequisites
:class: tip
You will need to be logged in to the HPC to run these commands
:::

### qstat command

This command will return the current status of all the queues:

```{code} bash
:linenos: true
:emphasize-lines: 1
qstat -q
```

```{code} bash
:label: qstat
:caption: example output of the qstat command
server: aqua

Queue            Memory CPU Time Walltime Node   Run   Que   Lm  State
---------------- ------ -------- -------- ---- ----- ----- ----  -----
cpu_batch_exec  16384gb    --    48:00:00  --    643  2361   --   E R
cpu_batch          --      --       --     --      0     0   --   E R
cpu_inter_exec     34gb    --    12:00:00  --      4     0   --   E R
cpu_inter          --      --       --     --      0     0   --   E R
gpu_batch_exec   1920gb    --    48:00:00  --     34     1   --   E R
gpu_batch          --      --       --     --      0     0   --   E R
gpu_inter_exec     68gb    --    12:00:00  --      5     0   --   E R
gpu_inter          --      --       --     --      0     0   --   E R
cpu_batch_exlm   6015gb    --    48:00:00  --      0     0   --   E R
                                               ----- -----
                                                 686  2362
```

The queues that end in `exec` are the execution queues, but the queues that don't end in `exec` are routing queues where jobs are submitted.

(pbsnodeinfo-queue-limits)=
### pbsnodeinfo

This command will return the nodes and their resources.

```{code} bash
:linenos: true
:emphasize-lines: 1
pbsnodeinfo
```

```{code} bash
:label: pbsnodeinfo
:caption: example output of the pbsnodeinfo command

Node      :     cpu_id    | cpu usage | cpu% | mem usage | mem% |  gpu; gpu usage
====================================================================
  cpu1n001:     AMD-25-17 |  187/188  |  99  |  860/1479 |  58  |
  cpu1n002:     AMD-25-17 |  188/188  | 100  |  925/1479 |  62  |
  ...
  gpu1n001:   Intel-6-143 |   18/168  |  10  |   88/ 974 |   9  | H100; 2/28 gpus
  gpu1n002:   Intel-6-143 |   96/168  |  57  |  452/ 974 |  46  | H100; 4/ 4 gpus
  ...
  mem1n001:     AMD-25-17 |   64/180  |  35  | 1500/6014 |  24  |
```
:::{note} Explanation of `pbsnodeinfo` stats
*The results of the `pbsnodeinfo` command shows what resources are currently in use and the total resources on each node. So, in this example `cpu1n001` shows 187 of the available 188 CPUs are in use (99%) and 860GB of the available 1479GB memory are in use (58%). Also, `gpu1n002` shows 96 of the 168 CPUs are in use (57%), 452GB of the 974GB of memory are in use (46%) and all 4 of the available H100 GPUs are also in use.*
:::

This information can be used in determining the scheduable resources of the nodes in the cluster. Each [chunk](../../Miscellaneous/hpc-appendix-what-do-these-terms-mean.md/#chunk) in the submission statement (e.g. `select=1:ncpus=10:mem=120GB`) must fit within these limits to be placed on an available node.

***
[Back to the top](#queue-limits-heading-target)
***

**For further help contact eResearch** \
Submit a ticket: [http://qut.to/eresearch-support](http://qut.to/eresearch-support) \
Email us: eresearch@qut.edu.au \
Call us: 07 3138 8899
