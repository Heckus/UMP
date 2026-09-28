---
title: Submitting PBS Jobs part 1
date: 2026-09-09
subject: tutorial
exports:
  - format: docx
---
(submitting-pbs-jobs-part-1-training-heading-target)=

## Requesting Resources

Before you can run your software analysis on the HPC, suitable resources must be reserved for you. You must determine the resources needed to run your software before you submit your job. If you do not request enough CPUs, your analysis may run slower than intended. If your request does not request enough memory, the PBS scheduler will kill your job if it tries to allocate more than the limit. The PBS scheduler will also kill your job if it has not finished before time you requested in your job.

It can be a chicken and the egg situation as you may not know what resources you need to request. At the end of your job, PBS will create a job log or summary of the resources you used. You can use this job log summary to tune your job requests. There is more information here about [monitoring these job logs.](../../../Aqua/Getting_started/hpc-job-monitoring.md/#job-logs) 

Asking for slightly more resources than you need is good to ensure your job finishes successfully, but the more resources you ask for, the longer it usually takes before your job starts. So if you over estimate, use the job log information to lower your request for the next job. A good place to start is if you have run the analysis on your laptop, you can start with the resources that your laptop has, typically 4 cpus and 16gb.

## Types of Resources

PBS tracks the following resources which you must request in your job:

*   `ncpus`: The number of CPUs you need. Generally, the more CPUs you ask for, the faster your job will run (up to a limit). Specified as a number such as 2. However, just adding more CPUs to your request will not make your calculation go faster unless the software supports more. Most software supports just one CPU while some can support 2, 4, 8 or more CPUs.
    
*   `mem`: The amount of memory your analysis needs. Typically requested in gigabytes (gb). Be relatively generous here, if you do not request enough, your job will be killed! Specified as a number with a unit, 8gb.
    
*   `walltime`: How long you need to run your analysis. If you analysis is not finished by this time, it will be killed. Consider using a minimum of 1 hour to reduce the work the scheduler does. Specified in Hours:Minutes:Seconds, eg 4:00:00 for 4 hours, zero minutes and zero seconds. The maximum walltime for interactive jobs is 12hrs and for batch jobs is 48hrs.

*   `-P <RPID>`: The {abbr}`RPID (Research Plan ID)` that refers to the project that your job belongs to. If you do not currently have a Data Management Plan with an {abbr}`RPID (Research Plan ID)`, then please log in to the [{abbr}`DMP (Data Management Planner)`](https://data-mgmt-plan.qut.edu.au/) and create a plan.
    

Other resources can be requested but considered optional:

*   `ngpus`: Select one or more GPUs for your job. Only select if you know your software can use a GPU.
    
*   `cpu_id`: Select the type of CPU you want to use, if your analysis has a preference. For example, you can use `cpu_id=AMD-25-17`.
    

## Types of Jobs

When running software on the HPC, we do NOT run the apps on the Login Node. Since the Login node is shared amongst all the connected HPC users, we don’t want you slowing everyone else down, and we don’t want others slowing you down. To run any software, we need to submit a job.

The workhorse of the PBS is the Batch Job. This job type is where you request resources and software that will run without asking questions. This is important because if your software stops to ask you a question like “press Y to continue” there is no one to press Y. When you submit a Batch Job, PBS may run it at 3am the next morning. You do not have to wait, simply submit your Batch Job and move on.

Sometimes it may be difficult to find the right software that will run on the HPC, or you might need to experiment with providing command line options. An Interactive job can help here. When you submit an Interactive job, your terminal stops accepting input until the job is allocated to a node and starts. When it starts, you will be transfered to the node. This session is not shared, you can run apps without effecting others.

## Helpful Tools

The command to submit jobs is **qsub**. qsub has many options and you find out all of them by accessing qsub’s man page, via the `man qsub` command.

To check on the status of your jobs, use the **qstat** command. Another tool written by QUT HPC staff is **qjobs**.

We also have an [HPC Monitoring Dashboard](https://hpc-monitoring.eres.qut.edu.au/), where you can monitor your job's resource usage in real time so that you can optimise the selection of # of CPUs, memory etc.

## Launching an Interactive job

To launch an Interactive job, we need to supply the necessary options to `qsub`. Let's launch a small Interactive job, with 1 CPU and 1gb of memory for 1 hour. Remember to replace the `ABCDEF1234` parameter with the appropriate {abbr}`RPID (Research Project ID)` that you have access to:

```{code} bash
:linenos:
:emphasize-lines: 1
qsub -I -l select=1:ncpus=1:mem=1gb -l walltime=1:00:00 -P ABCDEF1234
```

You will see:

```
qsub: waiting for job {job id} to start
qsub: job {job id} ready

{username}@{node}:~>
```

You are now connected to the node assigned to your job and you can run commands. Notice how the server name (after the @ symbol) has changed. We can now run commands that use all of the resources we requested. These resources are not shared like the Login Node.

We shall keep this job running for the next section.

Note, there is information about resource [limits for interactive jobs](../../../Aqua/Getting_started/hpc-submitting-jobs-on-aqua.md/#cpu-only-interactive-jobs)

***
Before you move on to the next section, try these `QUIZ questions` to test your knowledge of material on this page:

:::{attention}QUIZ Question 11
How would you submit a basic interactive job for the minimum amount of resources? \
(Single choice)*
1. `qsub -l select=1:ncpus=1:mem=1gb -l walltime=00:00:01 -P ABCDEF1234`
2. `qsub -l select=1:ncpus=1:mem=1gb -l walltime=01:00:00 -P ABCDEF1234`
3. `qsub -l select=1:ncpus=1:mem=1gb -l walltime=12:00:00 -P ABCDEF1234`
4. `qsub -I -l select=1:ncpus=1:mem=1gb -l walltime=00:10:00 -P ABCDEF1234`

:::{attention} Show me the Solution
:class: dropdown
1. Incorrect. This minimum walltime is 10 minutes not 1 second, also this command is missing the `-I` option that tells PBS that it is an interactive job
2. Incorrect. This command is missing the `-I` option that tells PBS that it is an interactive job
3. Incorrect. This command is missing the `-I` option that tells PBS that it is an interactive job and which shell to use
4. Correct. This command will create an interactive job with 1 CPU on 1 node with 1GB of memory for 10 minutes
:::






* * *
[Back to the top](#submitting-pbs-jobs-part-1-training-heading-target)
* * *

**For further help contact eResearch** \
Submit a ticket: [http://qut.to/eresearch-support](http://qut.to/eresearch-support) \
Email us: eresearch@qut.edu.au \
Call us: 07 3138 8899