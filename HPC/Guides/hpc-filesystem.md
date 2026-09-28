---
title: Filesystem and data management
date: 2026-03-24
---
(filesystem-and-data-management-heading-target)=

****Files are stored on Aqua in a few different locations, depending on who requires access.****

:::{admonition} Prerequisites
:class: tip
You will need to be logged in to the HPC to access these file system locations OR \
You will need to have mapped the HPC-FS to your computer to access these file system locations
:::

# Summary of important filesystems mounted on Aqua
* `/home/$USER` - filesystem for each user to store files and run scripts (only accessible by that user). This folder is created the first time you log on to the HPC. Note, the {abbr}`$USER (this $USER variable represents your username)` specified here, is shown as your `username` on the HPC.
  * Note: when you first log in to the HPC, your working directory is your `/home/$USER` folder
  * Filesystem type: Lustre
  * Variable: {abbr}`$HOME (This $HOME variable represents the path to your HOME directory)`
  * Regularly backed up

***
* `/home/$USER/bin` - folder where users can install software for themselves.
  * Regularly backed up
  * This folder is created for you the first time you log on to the HPC
  * Note: the path needs to be added to your `.bashrc` file so the folder can be searched automatically for software:
```{code} bash
:linenos:
:emphasize-lines: 1,2
export PATH="/home/$USER/bin:$PATH" >> /home/$USER/.bashrc
source /home/$USER/.bashrc
```
***
(scratch)=
* `/scratch/` - high performance, parallel filesystem to be used for read/write (i.e. I/O) operations. 
  * Filesystem type: Weka
  * Not backed up
  * While the `/scratch/` folder is already set up, you need to make a folder within the `/scratch/` folder for your specific projects and remove it after you've finished running all analysis for that project.
  * Data is to be stored here only for the short-medium term (deleted if inactive after 30 days):
```{code} bash
:linenos:
:emphasize-lines: 1,2,4
mkdir -p /scratch/<USER_project> # make a directory on scratch for project files
cp input_file.R /scratch/<USER_project>/ # copy any input files etc
#then reference the scratch path within your batch job script
Rscript /scratch/<USER_project>/input_file.R 
```

***
(tmpdir)=
* `$TMPDIR` - filesystem available within a batch job that has fast read/write (i.e. I/O) operations for temporary files (automatically removed when job is finished).
  * Filesystem type: Weka
  * Not backed up
  * This folder is created for you when you submit a batch job and only exists within that job
  * Example of how to write your output file to {abbr}`$TMPDIR (This $TMPDIR variable represents the job-specific temporary directory for a specific job)` and copy it back `within your batch job script`:
```{code} bash
:linenos:
:emphasize-lines: 1,3

mpirun -np 40 lmp_mpi < in.term > /$TMPDIR/term.lmp
# remember to copy back the file to your working directory within the job script
cp /$TMPDIR/term.lmp $PBS_O_WORKDIR/term.lmp 
```
***
* `/usr/local/bin` - folder where symbolic links to general PBS scripts are located (accessible for each user).
  * e.g. `pbsnodeinfo`, `qjobs`, `time_until_outage.sh` etc.
  * This folder is created for you the first time you log on to the HPC and you shouldn't need to do anything with it.
***
(work)=
* `/work/` - filesystem for work group or shared files and folders.
  * Filesystem type: Lustre
  * Regularly backed up
  * If you work on a project with collaborators, you can request a shared `/work/` folder to share input files, scripts, analysis results etc between you and your collaborators
  * To request a shared `/work/` folder, submit an [eResearch Help Centre portal ticket](https://eresearchqut.atlassian.net/servicedesk/customer/portals), select `HPC request` ticket type, `New shared folder` and specify the usernames of those who need access to it. Any files and folders you create within your `/work/` shared folder will have the same file permissions as the parent folder (by default).
***
* `/work/datasets/` - filesystem for storing common datasets/files that take a lot of resources to download (i.e. large file size or large numbers of files) or where access can be shared with everyone. File permissions can still be restricted to work groups if required.
  * Filesystem type: Lustre
  * Regularly backed up
  * e.g. Ansys Fluent manuals are located here `/work/datasets/ansys_manuals`


```{note}
Lustre filesystem is a 5PB filesystem made up of Non-volatile Memory Express (NVME) and spinning disks. Its capable of 800,000 I/O and 100GB/sec throughput.

Weka filesystem is a 1PB filesystem made up of NVME and it is capable 17 Million I/Os and 500GB/sec throughput.

Both filesystems are attached to the compute nodes via infiniband (HDR and NDR).
```

***
# File system best practice tips

To ensure system performance and accessibility for all users, we request that users do not keep large numbers (i.e. millions) of files in their `/home/$USER` directory. When files and folders in a user's home directory are not needed on a daily basis, they can be archived by using the `tar` command like this (replacing the `<foldername>` with the name of the folder needing to be archived):
```{code} bash
:linenos:
:emphasize-lines: 1
tar -cvf <foldername>.tar <foldername>
```
Then the `<foldername>` folder (and contents) needs to be removed.

# Data management
Use the Data Management Planner (DMP) to reflect on your research data needs and create a data management plan. If you're new to data management, a pre-plan checklist is included to help you consider the information required and to inform discussions with your supervisor.

Link to [DMP](https://data-mgmt-plan.qut.edu.au/)

Link to [Managing research data and primary materials](https://qutvirtual4.qut.edu.au/group/staff/research/conducting/managing-research-data)

More information about data curation can be found on the [Data Curation Network website](https://datacuration.network/curator-resources/)

***
[Back to the top](#filesystem-and-data-management-heading-target)
* * *
:::{admonition} Useful other resources
:class: hint
* [Data Curation Network](https://datacuration.network/curator-resources/)
* [Data curation primers](https://github.com/DataCurationNetwork/data-primers/tree/main)
:::
***

**For further help contact eResearch** \
Submit a ticket: [http://qut.to/eresearch-support](http://qut.to/eresearch-support) \
Email us: eresearch@qut.edu.au \
Call us: 07 3138 8899