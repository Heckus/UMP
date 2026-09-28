---
title: Submitting PBS Jobs part 2
date: 2026-09-09
subject: tutorial
exports:
  - format: docx
---
(submitting-pbs-jobs-part-2-training-heading-target)=

## Launching a Batch Job - Constructing a Job Script

It is possible to submit a batch job completely from the command line, saving the job parameters and commands in a text file is very handy for documenting you use of the HPC. In a job script `#PBS` is used to provide instructions to PBS, they are not run as commands. A small script is described below (remember to replace the `ABCDEF1234` with an appropriate `RPID` that you are a member of):

```{code} bash
:linenos:
:emphasize-lines: 2,3,4
#!/bin/bash -l
#PBS -l select=1:ncpus=1:mem=2gb
#PBS -l walltime=00:10:00
#PBS -P ABCDEF1234

echo $(hostname)
```

This job will request one node (select=1), one cpu (ncpus=1), 2gb of memory (mem=2gb) and run for a maximum of 10 minutes (walltime=00:10:00)

Notice how the options after **#PBS** are the same as the **qsub** command line?

This script is very basic, it will run the command hostname, which outputs the name of the computer this job is running on, and then echo that to the screen.

While the name of the file is not important, I like to save my PBS job scripts as {name}.pbs to easily identify them in the file list. Use **training01.pbs** here.

Let’s use nano to create the file. Nano is provided by default on Aqua, so to create the file:

```{code} bash
:linenos:
:emphasize-lines: 1
nano training01.pbs
```

After you create a new file (or just want to look at the text in a file), you can use the `cat` command to print the file to screen:

```{code} bash
:linenos:
:emphasize-lines: 1
cat training01.pbs
```

(launching-a-batch-job-submitting-a-job-script-training)=
## Launching a Batch Job - Submitting a Job Script:
## Example 1

Since all the options are contained in the job script, the **qsub** line is short:

```{code} bash
:linenos:
:emphasize-lines: 1
qsub training01.pbs
```

And you will see a job number printed on the screen. Use **qjobs** to check on the status of the job.

### Checking on the Job Status

To quickly check on your jobs that are queued and running, use the **qjobs** command

```{code} bash
:linenos:
:emphasize-lines: 1
qjobs
```

You will get a summary of each queued job and the running ones. The finished ones are not displayed.

An alternative way to list your jobs:

```{code} bash
:linenos:
:emphasize-lines: 1
qstat -u $user
```

Get more details about a particular job:

```{code} bash
:linenos:
:emphasize-lines: 1
qstat -f {jobid}
```

### Checking the Output

Since we told the job to print the name of the node the job was running on, how do we see it? PBS will save the output of the commands run in the job into two files by default. The format is `{job name}.o{job id}` and `{job name}.e{job id}`.

Let's examine these files:

```{code} bash
:linenos:
:emphasize-lines: 1,2,3,4,5,6,7,8,9
# find the files by listing the contents of the folder sorted by reverse date
ls -ltr
# the 'e' file is empty
cat training01.pbs.o{tab}
cpu1n024
PBS Job 5228698.pbs
CPU time  : 00:00:00
Wall time : 00:00:02
Mem usage : 0b
```

We can see in this case, the job ran on the `cpu1n024` node, used no measurable cpu and memory, and lasted for 2 seconds. The two files represent the standard output and the standard errors of the commands. The name of the files and merging them is possible with more options.

### Deleting a job
If you need to delete a queued or running job, for example if you realised that you didn't request enough memory and want to change it, you can use the **qdel** command:

```{code} bash
:linenos:
:emphasize-lines: 1
qdel {jobid}
```


### More options in job scripts

We have just scratched the surface of what you can specify when you submit and run jobs. A few useful ones are:

*   Be notified when the job starts, using the -m option, e.g. be sent an email if the job is aborted, when it begins, and when it ends: `#PBS -m abe`
    
*   Give the job a name: To find your job in a long list give it a meaning name with the -N option: `#PBS -N MyJob01`
    
*   Merge the error file into the standard output file: `#PBS -j oe`
    
*   Overriding the email address: If you want to send the job notification email to another address, use the -M option, eg `#PBS -M bob@bob.com`
    

## Example 2

From the `Introduction to the Unix Shell` for HPC users course lets run the do-stats.sh script as a job.

First, change to the folder:

```{code} bash
:linenos:
:emphasize-lines: 1
cd ~/workshop/Intro_to_HPC/shell-lesson-data/north-pacific-gyre
```

Then, create the submission script (copy and paste!).

When you copy and paste this script, remember to replace the `ABCDEF1234` parameter in line 5 with the appropriate {abbr}`RPID (Research Project ID)` that you have access to:

```{code} bash
:linenos:
:emphasize-lines: 9,10,11,12,13,14
#!/bin/bash -l
#PBS -N GooStatsRun01
#PBS -l select=1:ncpus=1:mem=2gb
#PBS -l walltime=00:30:00
#PBS -P ABCDEF1234
#PBS -m abe
cd $PBS_O_WORKDIR

# Calculate stats for data files.
for datafile in NENE*A.txt NENE*B.txt
do
    echo $datafile
    bash goostats.sh $datafile stats-$datafile
done
```

Call this PBS batch job script **do-goostats.pbs**

Now submit to the scheduler:

```{code} bash
:linenos:
:emphasize-lines: 1
qsub do-goostats.pbs
```

And check the status:

```{code} bash
:linenos:
:emphasize-lines: 1
qjobs
```

After its finished running, check the output:

```{code} bash
:linenos:
:emphasize-lines: 1,2,3,4,5,6,7,8
ls -ltr
cat GooStatsRun01.o{job_id}
...
CPU time  : 00:00:00
Wall time : 00:00:33
Mem usage : 4648kb
cat GooStatsRun01.e{job_id}
{Empty File}
```

## Tricks and Tips

When the job starts, PBS will logon to the node as you, and your working directory will be your home folder. If your data is in a sub folder or in a shared folder, you can use this line to automatically change to that folder:

```{code} bash
:linenos:
:emphasize-lines: 1
cd $PBS_O_WORKDIR
```

`$PBS_O_WORKDIR` is a special environment variable created by PBS. This will be the folder where you ran the `qsub` command.

## Example 3

We can run commands to check and trim fastq sequences.

Start by changing directory:

```{code} bash
:linenos:
:emphasize-lines: 1
cd $HOME
```

Then, download the data and scripts into a specific folder:

```{code} bash
:linenos:
:emphasize-lines: 1
wget -P ~/workshop/Intro_to_HPC https://github.com/eresearchqut/hpc_training_3/archive/refs/tags/1.2.tar.gz
```

Then, change to the folder where the data is downloaded:

```{code} bash
:linenos:
:emphasize-lines: 1
cd ~/workshop/Intro_to_HPC
```

Then, unpack the downloaded file with the tar command:

```{code} bash
:linenos:
:emphasize-lines: 1
tar -xvzf 1.2.tar.gz
```

Change into the newly create folder (Don’t forget TAB completion):

```{code} bash
:linenos:
:emphasize-lines: 1
cd hpc_training_3-1.2
```

Examine the data and scripts

```{code} bash
:linenos:
:emphasize-lines: 1,2
ls
cat stage1.pbs
```

**stage1.pbs**

When you copy and paste this script, remember to replace the `ABCDEF1234` parameter in line 6 with the appropriate {abbr}`RPID (Research Project ID)` that you have access to:

```{code} bash
:linenos:
:emphasize-lines: 1,4,5,6,9,12,15,18
#!/bin/bash -l
#PBS -N Stage1-FastQC
#PBS -m abe
#PBS -l select=1:ncpus=2:mem=4gb
#PBS -l walltime=1:00:00
#PBS -P ABCDEF1234

# Change to folder where we launched the job
cd $PBS_O_WORKDIR

# Make a directory for the fastqc results
mkdir fastqc

# Load the fastqc module
module load FastQC/0.12.1-Java-11

# Run fastqc
fastqc --threads 2  --outdir fastqc data/sample1_R1.fastq.gz data/sample1_R2.fastq.gz
```

This job script will load the `fastqc` app from the module system and run with the samples. This job script will also produce the fastqc directory that holds the results of the run.

When you copy and paste this script, remember to replace the `ABCDEF1234` parameter in line 6 with the appropriate {abbr}`RPID (Research Project ID)` that you have access to:

**stage2.pbs**

```{code} bash
:linenos:
:emphasize-lines: 1,4,5,6,9,12,15,16,17,19,20,21
#!/bin/bash -l
#PBS -N Stage2-seqtk
#PBS -m abe
#PBS -l select=1:ncpus=2:mem=8gb
#PBS -l walltime=1:00:00
#PBS -P ABCDEF1234

# Change to folder where we launched the job
cd $PBS_O_WORKDIR

# Make a directory for the seqtk results
mkdir trimmed

# Use Singularity to supply trim the files
singularity exec https://depot.galaxyproject.org/singularity/seqtk:1.4--he4a0461_1 bash -c \
  'seqtk trimfq data/sample1_R1.fastq.gz | \
  gzip --no-name > trimmed/sample1_R1.fastq.trimmed.gz'

singularity exec https://depot.galaxyproject.org/singularity/seqtk:1.4--he4a0461_1 bash -c \
  'seqtk trimfq data/sample1_R2.fastq.gz | \
  gzip --no-name > trimmed/sample1_R2.fastq.trimmed.gz'
```

This job script will run the `seqtk` app over the sample fastq files using default settings. Since seqtk is not available on the HPC, we can use singularity to supply the app. This script will saved the trimmed fastq files in the trimmed folder.

**stage3.pbs**

When you copy and paste this script, remember to replace the `ABCDEF1234` parameter in line 6 with the appropriate {abbr}`RPID (Research Project ID)` that you have access to:

```{code} bash
:linenos:
:emphasize-lines: 1,4,5,6,9,12,15,16
#!/bin/bash -l
#PBS -N Stage3-multiqc
#PBS -m abe
#PBS -l select=1:ncpus=2:mem=8gb
#PBS -l walltime=1:00:00
#PBS -P ABCDEF1234

# Change to folder where we launched the job
cd $PBS_O_WORKDIR

# Make a directory for the seqtk results
mkdir multiqc

# Use Singularity to supply trim the files
singularity exec https://depot.galaxyproject.org/singularity/multiqc:1.21--pyhdfd78af_0 \
  multiqc --force --outdir multiqc data fastqc trimmed
```

This job script will run `multiqc` to create a summary of the data and operations of the previous stages. Like `seqtk` run in stage2, multiqc is not available on the HPC so we can run it via singularity. The results will be saved in the multiqc folder.

These files must be run one after each other, they cannot run at the same time.

Launch `stage1.pbs`

```{code} bash
:linenos:
:emphasize-lines: 1,2,3,4
qsub stage1.pbs
qjobs
cat Stage1.o{tab}
cat Stage1.e{tab}
```

When finished, launch `stage2.pbs`

```{code} bash
:linenos:
:emphasize-lines: 1,2,3,4
qsub stage2.pbs
qjobs
cat Stage2.o{tab}
cat Stage2.e{tab}
```

Finally, when stage2 is finished, launch `stage3.pbs`

```{code} bash
:linenos:
:emphasize-lines: 1,2,3,4
qsub stage3.pbs
qjobs
cat Stage3.o{tab}
cat Stage3.e{tab}
```

These jobs will send you an email when the job starts and finishes. It can be handy to receive the email rather than watching `qjobs` etc.

Once stage3 is finished, open up the `hpc_training_3-1.2` folder in Windows Explorer/Finder and examine the files, especially in the multiqc folder.

![image-20240911-065224.png](./attachments/image-20240911-065224.png)
***
Before you move on to the next section, try these `QUIZ questions` to test your knowledge of material on this page


:::{attention}QUIZ Question 13
You have prepared your PBS batch job script and called it `launch_analysis.pbs`, how would you submit it to the PBS scheduler? \
(Single choice)*
1. `qsub launch_analysis.pbs`
2. `qjobs launch_analysis.pbs <username>`
3. `qstat -f launch_analysis.pbs`
4. `qsub 12345678.aqua`

:::{attention} Show me the Solution
:class: dropdown
1. Correct, using the `qsub launch_analysis.pbs` command will submit the PBS job script called `launch_analysis.pbs`
2. Incorrect. In fact, this `qjobs launch_analysis.pbs <username>` command will just return an error, as the `qjobs` command tells you about your current jobs (i.e. in either the `Q`ueued or `R`unning state) but you don't need to specify your `<username>` nor a `<filename>` to use it
3. Incorrect. In fact, the `qstat -f launch_analysis.pbs` command doesn't submit jobs, plus it is mis-specified for what the `qstat` command does do so it will just return an error, as the `qstat` command requires a job number to return statistics about the job
4. Incorrect. In fact, the `qsub 12345678.aqua` command will return an error, as the `qsub` command submits PBS job scripts to the PBS job scheduler so it requires a `<filename>` not a job number
:::

:::{attention}QUIZ Question 14
How would you set up a PBS batch job script so it set you an email to your default QUT email address associated with your username when the job begins and ends only? \
(Single choice)*
1. Add this line to your PBS batch job script: `#PBS -m abe`
2. Add these lines to your PBS batch job script: `#PBS -m abe` and `#PBS -M <username>@gmail.com`
3. Add this line to your PBS batch job script: `#PBS -m be`
4. Add this line to your PBS batch job script: `#PBS -M b e`

:::{attention} Show me the Solution
:class: dropdown
1. Incorrect, adding this line `#PBS -m abe` to your PBS batch job will send an email on your job `a`borting, `b`egining and `e`nding
2. Incorrect, adding these lines `#PBS -m abe` and `#PBS -M <username>@gmail.com` will send an email on your job `a`borting, `b`eggining and `e`nding, plus it will send the email to your gmail address not your default QUT address
3. Correct, adding this line `#PBS -m be` will send an email by default to your QUT address and only when your job `b`egins and `e`nds
4. Incorrect, adding this line `#PBS -M b e` will not send an email because the `-M` option requires an email address
:::

:::{attention}QUIZ Question 15
How can you tell the state of a job you just submitted? \
(Multiple choices are correct)*
1. If you have the job number, you can use the command: `qstat -fx <jobid>`
2. Use the command: `qjobs` and look for the one you just submitted
3. Wait until the walltime expires and go looking for output files
4. Go to the folder where you submitted it and keep typing the `ls` command every minute until you see the output files

:::{attention} Show me the Solution
:class: dropdown
1. Correct, this command `qstat -fx <jobid>` shows you the `f`ull information about your job and by adding the `x` it will also show you the full info about that job if it failed quickly
2. Correct, the command `qjobs` will show you all your current jobs in either the `R`unning or `Q`ueued state
3. Incorrect, this would not tell you about the current state of your job, only once it finished
4. Incorrect, this would also be a very slow way to find out info about your job
:::

:::{attention}QUIZ Question 16
How would you investigate how your job ran, after it finished? \
(Multiple choices are correct)*
1. Look at the standard output and error files
2. Look for the results file that you analysis should produce (if any)
3. Look at your PBS batch script that you submitted
4. Use the command: `qstat -fx <jobid>`

:::{attention} Show me the Solution
:class: dropdown
1. Correct, looking at the standard output and error files will show you how much resources your job used and any output to screen in the `o`utput file and any errors in the `e`rror file
2. Incorrect, your analysis might produce an results file even if something went wrong with your job so don't rely purely on the fact that you have an results file as it might be incomplete
3. Incorrect, the PBS batch script that you submitted will not display any information about how the job actually ran
4. Correct, the command: `qstat -fx <jobid>` will show info about your job including a comment line near the bottom that should tell you if it `finished` or `failed`
:::

:::{attention}QUIZ Question 17
Where would you find information about how much memory your job used? \
(Multiple choices are correct)*
1. Look in your PBS batch job script for how much memory you requested
2. Look at the standard output file where it should show resource utilisation statistics about the job
3. Use the command: `qstat -fx <jobid>` and look for the line that starts: `resource.used_mem`
4. Use the command: `qstat -u <username>` and scroll down until you find the job number, and the memory used is the last number on the line

:::{attention} Show me the Solution
:class: dropdown
1. Incorrect, this option only tells you about how much memory you requested, which may or maynot be what your job actually used
2. Correct, the standard output file will show resource utilisation statistics about the job
3. Correct, the command `qstat -fx <jobid>` will include a line that shows the `resource.used_mem`
4. Incorrect, the command `qstat -u <username>` will show you some info about your jobs but only `Req'd Memory` not used memory
:::

***
:::{note} Quiz and Assignment
Once you have reviewed the training material [Introducing the Shell](../../shell-novice/sn-index.md/#shell-topics) and [Intro to the HPC](../2025s1w1-eresearch-session-2-intro-to-hpc.md/#hpc-topics), there is a [Canvas Quiz and Assignment](https://canvas.qut.edu.au/enroll/CBHXG7) to test your knowledge. This link will self-enrol you into the HPC Licence course, where 'Part 1: HPC Fundamentals License Quiz', 'Part 2: Assignment questions' and 'Part 2: Assignment Upload to Gradescope' can be found under the modules menu item.
:::
* * *
[Back to the top](#submitting-pbs-jobs-part-2-training-heading-target)
* * *

**For further help contact eResearch** \
Submit a ticket: [http://qut.to/eresearch-support](http://qut.to/eresearch-support) \
Email us: eresearch@qut.edu.au \
Call us: 07 3138 8899
