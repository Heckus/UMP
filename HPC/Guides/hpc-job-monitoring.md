---
title: Monitoring Job Resource Usage
date: 2026-09-08
---
(monitoring-job-resource-usage-target)=

****When you are running jobs on the HPC, you have exclusive use of the resources you ask for in the Job. Since the HPC is a shared resource, if you ask for too many resources like more CPUs than what you are using, or more memory than what is required, these resources go to waste. By monitoring your jobs, you can optimize the resources you request. The fewer resources you ask for, the faster your job will start. You need to balance starting time with running time.****

(job-logs)=
# Monitoring the Job Log Files
PBS keeps track of your job resource usage and provides a printout of the CPU, Memory, and GPU usage at the end of each job. By default PBS will create a standard output file (filename looks like this `{Jobname}.o{jobid}`) and standard error file (filename looks like this `{Jobname}.e{jobid}`) in the folder you submitted the job in. These files contain what was printed to the screen on the node that was running your job. At the end of the `o` file you will find a summary of the resources used.

For example, a CPU-only job will show these type of statistics:
```{code} bash
PBS Job 1954613.aqua
CPU time  : 00:22:38
Wall time : 00:07:55
Mem usage : 5293996kb
```
This job ran for `Wall time : 00:07:55` (i.e. 7 minutes and 55 seconds) and used up to `Mem usage : 5293996kb` of ram (i.e. 5gb). The `CPU time` indicates how busy the CPUs were. Here, more than one CPU was busy (i.e. `22:38/07:55` ~3 CPUs were working at ~95% in the job). 

The user who submitted this job actually requested `ncpus=48` and `mem=96gb` of ram in the PBS job script. Therefore, this job wasted large amounts of resources on the HPC. If the user were to resubmit this job or change the data, they could use this information to change the CPUs requested from `ncpus=48` to `ncpus=3` or `ncpus=4` and the memory to `mem=8gb` to get closer to what the job actually needed to run.

(joining-your-std-error-and-std-output-files-together)=
## Joining your std error and std output files together
If you join them into one file, you'll have less places to look for info about your job, which can make life easier. You would do that be adding this `#PBS -j oe` line to your PBS job script, like this in line 5:
```{code} bash
:linenos:
:emphasize-lines: 6
#!/bin/bash -l
#PBS -N JOB_NAME
#PBS -l select=1:ncpus=1:mem=16gb
#PBS -l walltime:02:00:00
#PBS -P ABCDEF1234
#PBS -j oe
```
(saving-your-std-error-and-output-files-in-a-folder)=
## Saving your std error and output files in a folder
If it would be more convenient, you can save them in a specific folder, like this (you need to make the folder first):
```{code} bash
:linenos:
:emphasize-lines: 1,2,3,4,5,6
mkdir MATLAB_job_errors
```

```{code} bash
:linenos:
:emphasize-lines: 6,7
#!/bin/bash -l
#PBS -N JOB_NAME
#PBS -l select=1:ncpus=1:mem=16gb
#PBS -l walltime:02:00:00
#PBS -P ABCDEF1234
#PBS -o MATLAB_job_errors
#PBS -e MATLAB_job_errors
```


***
(real-time-hpc-monitoring)=
# Real-Time Job Monitoring
eResearch now offers a [HPC Monitoring Dashboard](https://hpc-monitoring.eres.qut.edu.au), which was created to monitor and optimise users HPC jobs. It is powered by a tool called Grafana. 

To access the HPC Monitoring Dashboard please visit:
[https://hpc-monitoring.eres.qut.edu.au](https://hpc-monitoring.eres.qut.edu.au)

```{important}
The HPC Monitoring Dashboard allows users to view how well their job is running, by showing users how much of the CPUs they requested are actually being used, how much of the memory is being used, and whether their GPU or MPI jobs are being efficient. It can be helpful for optimising resource requests for future jobs, **ensuring that users' jobs minimise the time spent queueing and maximise the usage of requested resources.**
```
***
## Logging in to the [HPC Monitoring Dashboard](https://hpc-monitoring.eres.qut.edu.au)

Please use your QUT Username (not email address) and QUT Password to logon (just like you do to access the HPC). 
```{note}
Users will need to have been granted HPC access in order to login and use the HPC monitoring dashboard.
```

```{image} attachments/Grafana_Login.png
:alt: Grafana login page
:width: 600px
:align: center
```

***
(home-screen)=
## Home screen
By default when you login to the [HPC Monitoring Dashboard](https://hpc-monitoring.eres.qut.edu.au), you will see a high-level summary of all your currently running jobs, or if you don't have any running jobs you will see a blank screen, like this:
```{image} attachments/Grafana_no_data.png
:alt: Grafana front page
:width: 700px
:align: center
```
\
You will notice there is a common arrangement on each of the [HPC Monitoring Dashboard](https://hpc-monitoring.eres.qut.edu.au) pages (for example see PBS User page below):
* Menu - top of page (blue box in image below)
* Selectors and Buttons - towards the top of page (yellow box underneath the Menu)
* Gauges and Summary numbers - middle of page (magenta box)
* Job list - bottom of PBS User page, which will contain links to PBS Jobs page for that job id
```{image} attachments/Grafana_no_data_outline_new.png
:alt: Grafana front page
:width: 800px
:align: center
```
\
The PBS Job page has more detailed information about each of your running jobs, but has similar sections to the PBS User page:
* Menu - top of page (blue box in image below)
* Selectors and Buttons - towards the top of page (yellow box underneath the Menu)
* Gauges and Summary numbers - middle of page (magenta box)
* Graphs over time - bottom of page (green box)
```{image} attachments/Grafana_PBS_Jobs_new.png
:alt: Grafana front page
:width: 800px
:align: center
```
***
(choosing-a-job)=
## Choosing a Job

When you choose the `PBS Job` menu you will automatically be presented with the details of the last job you submitted. You can choose to display information about other jobs with the `Job ID Selector` dropdown menu in the Selectors and Buttons area at the top of the page (blue arrow in below image): 
```{image} attachments/Grafana_MPI_nodes_all_new.png
:alt: Grafana Job Selector
:align: center
```
\
You can also choose the individual nodes in a multi-node job from the `Node Selector` (blue arrow in below image):
```{image} attachments/Grafana_MPI_nodes_new.png
:alt: Grafana Node Selector
:align: center
```
***

(changing-the-timeframe)=
## Changing the timeframe
If you want to change the timeframe displayed for your job (e.g. it has been running for 8 hours), go to the `Time Selector` in the Selectors and Buttons area (blue arrow in below image), it might say `Last 3 hours`:
```{image} attachments/Grafana_Timeframe_new.png
:alt: Grafana Job Selector
:align: center
```
\
Select the dropdown arrow and choose the timeframe you're interested in:
```{image} attachments/Grafana_Timeframe.png
:alt: Grafana Job Selector
:align: center
```
***
(refresh-the-graphs)=
## Refresh the Graphs
The [HPC Monitoring Dashboard](https://hpc-monitoring.eres.qut.edu.au) is a real-time view of your job usage, so you can choose to refresh the graphs by clicking the `Refresh Button` in the Selectors and Buttons area at the top of the page:
```{image} attachments/Grafana_Timeframe_Refresh_new.png
:alt: Grafana Job Selector
:align: center
```
\
You can also choose how often to refresh the graphs with the dropdown arrow (yellow arrow in below image):
```{image} attachments/Grafana_Auto-Refresh.png
:alt: Grafana Job Selector
:align: center
```
***
(job-details)=
## Job Details

The [HPC Monitoring Dashboard](https://hpc-monitoring.eres.qut.edu.au) shows the history of CPUs and threads used, CPU Efficiency, Memory Usage, Memory Efficiency, and the GPU usage (if requested) etc, for each job.


You can see this as Gauges and Summary numbers in the middle of the page, where you get a snapshot summarising the usage and efficiency of the job over the refresh timeframe:
```{image} attachments/Grafana_OMP_bad.png
:alt: Grafana Job Summary
:align: center
```
***
### CPU Usage
You can also see the CPU usage over the history of the job (or over the timeframe you chose in the Time Selector, e.g. `Last 1 hour`) from the Graphs over time area in the centre of the page:
```{image} attachments/Grafana_CPU_Graph.png
:alt: Grafana Job Selector
:align: center
```

We can see in the above graph that the CPUs are not being used efficiently. The yellow line shows the CPUs actually being used by the job, the blue line shows what the system used, and the green line is the total of both of these. We can see that maximum Total CPU usage only got up to 74.1% (`Total` line from `Max` column in summary table at bottom right of image) and most of the time was below 50% usage (`Total` line from `Mean` column in summary table).
***
### Memory Usage

You can also see the Memory Usage over the life of the job (or over the timeframe you chose in the Time Selector, e.g. `Last 1 hour`) from the Graphs over time area in the centre of the page:
```{image} attachments/Grafana_Mem_Usage.png
:alt: Grafana Job Selector
:align: center
```

We can see in the above graph that 100GB of memory was requested (green line in graph and `Requested` line in summary table at bottom right of image), but much less than this was used by the job (yellow line in graph). In fact, only about 16GB was used by the job most of the time (`Used` row from `Mean` column in summary table). By taking into account the maximum Memory used by the job (26.8GB from `Used` row from `Max` column in summary table), we can see that if the user had requested ~32GB instead of 100GB, the job would have run much more efficiently while still accounting for the peak in memory usage. The rest of that wasted memory (i.e. 68GB) could have been used by another user on the HPC. 

```{important}
As members of the QUT HPC User community, it is important that we be responsible about the resources we use, and that is why we talk about how important it is to optimise your job(s). 

```{note}
Another advantage of optimising the resources you request, is that the job would have wasted less time in the queue if 32GB had been requested instead of 100GB. 
```
***
## MPI Jobs
If you have used MPI in a job, check that all of your nodes actually have processes running on them, otherwise your software may not be capable of being run across multiple nodes and you may be wasting resources and time in the queue that is not needed.

When you first select the MPI job in the [HPC Monitoring Dashboard](https://hpc-monitoring.eres.qut.edu.au), you will see a summary of the whole job when `All` is in the `Node Selector` (blue arrow in below image):

```{image} attachments/Grafana_MPI_graphs_over_time_ALL.png
:alt: Grafana MPI job showing all node usage
:align: center
```
This is an example of a really well optimised `MPI` job, where you can see the user requested 12 CPUs and 12GB of memory (i.e. `select=12:ncpus=1:mem=1GB`), and the CPU usage is at > 100% of those requested and the memory usage is about 80% of that requested.

***
## Optimizing Jobs

``` {tip} Aim for 80%
Our aim is for users to have optimised their jobs so that at least 80% of the CPU (or GPU) and memory resources that they requested are being used.
```

If you look at one of your jobs and see your usage gauges are coloured `orange`, `yellow`, or `red`, this means that your usage of those resources is not ideal (i.e. below the 80%), see the usage for this `MPI` job below:
```{image} attachments/Grafana_MPI_bad_new_graphs.png
:alt: Grafana MPI job showing bad usage statistics
:align: center
``` 

If your `MPI` job looks more like this example, then you can use the dashboard to investigate further...

If you change the `Node Selector` to choose the first node the MPI job is running on, you may see that the job is really efficiently using that one node.

And if you change the `Node Selector` to choose one of the other nodes that the MPI job is running on, you may see that the job is not using any CPU resources on those other nodes at all.

This means that the analysis is either not capable of, or not correctly set up for, running across multiple nodes. So, this type of job should be investigated to correctly set it up to run across nodes, but if it can't be then it should not be run as `MPI` (i.e. multithreaded across nodes), but rather as `OMP` (i.e. multithreaded within a node).

```{tip} Using the dashboard to help optimise your resource requests
Once you learn how to monitor your jobs and discover what the CPU and Memory usage for a particular analysis was, you can use this information to choose the resource requests in your future jobs more accurately. Matching your resource request to what your job actually needs will have them running sooner, and allow more jobs to run at the same time.

There is more information about how to set up some test jobs in an efficient way to help figure out your job(s) optimal resources here: [Estimating/Optimising resources to request for a job](../Speeding_up/hpc-estimatingoptimising-resources-to-request-for-a-job/hpc-estimatingoptimising-resources-to-request-for-a-job.md)
```
***
(other-graphs)=
## Other Graphs

The other graphs on the [HPC Monitoring Dashboard](https://hpc-monitoring.eres.qut.edu.au) can also help you tune your job, for example:
* If you are using a lot of Disk IO, you should switch to using the Scratch filesystem `/scratch`. More info about `/scratch` is found [here](../Learning_more/hpc-filesystem.md/#scratch)\
  **Disk IO is found below Memory Usage in the Graphs over time area in the centre of the page.**
* If you see many more Processes or Threads than CPUs and your CPU usage is at 100%, running your job with more CPUs will likely speed up your analysis.\
  **Processes and Threads is found at the bottom of the Graphs over time area in the centre of the page.**
* If you requested a GPU and find you are not using it, stop your job and check your script/software.\
  **GPU Usage is found as a dropdown menu at the bottom of the Graphs over time area in the centre of the page.**


***
[Back to the top](#monitoring-job-resource-usage-target)
***

**For further help contact eResearch** \
Submit a ticket: [http://qut.to/eresearch-support](http://qut.to/eresearch-support) \
Email us: eresearch@qut.edu.au \
Call us: 07 3138 8899