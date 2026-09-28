---
title: Transferring files to or from the HPC
date: 2024-11-19
---
(transferring-files-heading-target)=

****It is very likely that you will need to transfer data to/from the {abbr}`HPC (i.e. aqua)`. There are a few methods available to transfer data...****

:::{admonition} Prerequisites
:class: tip
You will need to be logged in to the HPC to run some of these commands
:::

(using-file-explorer-or-finder-to-mount-or-map-a-drive-to-the-hpc)=

# Using File Explorer or Finder to mount or map a drive to the HPC

:::{dropdown} Windows
(on-a-windows-machine-using-file-explorer-on-your-desktop-or-laptop)=

## On a Windows machine, using File Explorer on your desktop or laptop

(map-a-drive-instructions)=

### Map a Drive instructions

Please ensure you have logged in to the HPC so a home directory is created for you, prior to attempting to map your home folder: [Connect to HPC](#how-you-log-into-aqua-depends-on-the-operating-system-of-your-computer)

To access your home folder on HPC when using Windows:

1. Connect to the QUT [VPN](https://qutvirtual4.qut.edu.au/group/student/it-and-printing/wi-fi-and-internet-access/accessing-resources-off-campus) if working remotely/off-campus
2. Open the File Explorer and right-click `Network` or `This PC` and choose Map network drive…

```{image} attachments/map_network_drive_1.png
:alt: Snapshot showing File Explorer and right-clicking on This PC
:width: 600px
:align: left
```

1. After you select `Map network drive...` a dialog will appear. Type in the following in the Folder box:
    `\\hpc-fs\<username>`, remembering to change `<username>` to your own username.

```{image} attachments/map_network_drive_2.png
:alt: Snapshot showing File Explorer with Map Network Drive dialog
:width: 600px
:align: left
```

1. Ensure `Reconnect at sign-in` is selected. Then choose `Finish`

2. You will be asked for your QUT user credentials
        In the user name field, type `qutad\` in front of your QUT username, then your password in the field below.

```{image} attachments/map_network_drive_3.png
:alt: Snapshot showing File Explorer with Enter network credentials dialog
:width: 600px
:align: left
```

Your home directory on HPC will now be mapped to the selected drive letter and may be accessed as usual. This means that next time you can type `\\hpc-fs\<username>` (remember to change `<username>` to your own username) into the path box in File Explorer, as a short-cut.

For the `/work/` folder, repeat the process, except use `\\hpc-fs\work` for the Folder box and select a different drive letter. There is more information about what the `/work/` folder is and when you might need to use it on the [Filesystem and data management page](../hpc-filesystem.md/#work) 

```{note}
Also, if you are using a QUT computer and have logged into it using a different username than you use to login to the HPC, then you will need to check the `Connect using different credentials` box on the `Map Network Drive` dialog.
```

From here, we can use the normal Windows file operations to copy to the {abbr}`HPC (i.e. aqua)`, copy from the {abbr}`HPC (i.e. aqua)`, copy/rename and delete files.

(dos2unix-program)=

### dos2unix program

When copying text files, you might be caught by the CRLF vs LF line endings. On Windows, regular text editors like Notepad put extra CR line endings on text files, which the {abbr}`HPC (i.e. aqua)` cannot process. To solve this problem, use the dos2unix program via the {abbr}`HPC (i.e. aqua)` command line to remove this extra character and make the file compatible with the {abbr}`HPC (i.e. aqua)`:

```{code} bash
:linenos:
:emphasize-lines: 1
dos2unix filename.txt
```

This is what you should see after running this command on the HPC:

```{image} attachments/dos2unix_aqua.png
:alt: Snapshot showing dos2unix script running on a test.txt file
:width: 600px
:align: left
```

***

**If you need to transfer large data files or a number of them to and from the {abbr}`HPC (i.e. aqua)` when you are not on campus and don’t want to use up all your data, you can map a drive on an rVDI machine and then use scp or sftp:**

1. #### *Getting access to the rVDI machines*

    If you don’t have access to the rVDI machines, you can request an account here: [Request access to rVDI](https://heat2.qut.edu.au/HEAT/Login.aspx?ProviderName=QUT+SAML&Role=SelfService&Scope=SelfService&CommandId=NewServiceRequestByOfferingId&Tab=ServiceCatalog&Template=72409A4512A34B2982A46AD6466AC440)

2. #### *Accessing the rVDI machines*

    Once you have an rVDI account, and using the VPN, you can access it either via the Omnissa Horizon Client software [Access rVDI via Omnissa](https://qutvirtual4.qut.edu.au/group/student/it-and-printing/software-and-learning-tools/vmware-horizon) or online via [Access rVDI online](https://rvdi.qut.edu.au/portal/webclient/#/home).

3. #### *Map a Drive - see instructions above*

    Follow the “**Map a Drive**” instructions [above](#map-a-drive-instructions).

4. #### *Copy the data*

    In Windows Explorer, open up one tab showing your local folders where you want to copy files from, and another tab showing the HPC drive you mapped in step 3, and copy using {kbd}`ctrl`+{kbd}`c` from the first tab and paste using {kbd}`ctrl`+{kbd}`v` into the second tab.

:::

:::{dropdown} Mac
(on-a-mac-using-finder)=

## On a Mac using Finder

Using the Mac Finder, we can connect to our Home folder and the shared Work folders on the {abbr}`HPC (i.e. aqua)`.

Open Finder and go to the Finder menu, select Go > Connect to Server,

for the home folder we type in the address bar (remember to replace the `username` with your own username):

**smb://hpc-fs/`username`/**

for the shared `/work/` folder we type in the address bar:

**smb://hpc-fs/`work`/**

*(There is more information abou the shared `/work/` area on the HPC at the [Filesystem and data management page](../hpc-filesystem.md/#work).)*

After typing the appropriate address in the address bar, press the connect button, and it should take you to a new Finder window showing the /`username`/ or /`work`/ folder that you just connected to (it may require your `username` and `password` the first time you connect this way). You will need to repeat these steps each time the connection is closed (i.e. when you log off/turn off your computer, or when your wifi cuts out). It should save the smb path in your favourite server list on the Connect to Server window for next time though.

:::{important}
If you are connecting from off-campus, you will need to use the VPN to access the server.
:::

[Back to the top](#transferring-files-heading-target)

(winscp-or-scp-or-sftp)=

# winscp or scp or sftp

:::{dropdown} Windows
(on-a-windows-machine)=

## On a Windows machine

(winscp)=

### WinSCP

You can also transfer files using tools like WinSCP (Or PSFTP in PuTTY). WinSCP can also convert text files as they are copied.

To connect you first need to configure your session, so start WinSCP, and then use the Login dialog that opens (see figure below). When configuring a session, most often you set a *File protocol*, *Hostname* and *User name*.

```{image} attachments/image-20231031-235331.png
:alt: Image showing PuTTY login window
:width: 800px
:align: center
```

***

Set the *File protocol* to SFTP, the *Hostname* to `eresdtn01.qut.edu.au`, and the *User name* to your {abbr}`HPC (i.e. aqua)` username. Once WinSCP opens up, it should look something like Windows File Explorer (see figure below) where you can see the remote host (i.e. eresdtn01) file structure on the left-hand pane. To transfer files to the {abbr}`HPC (i.e. aqua)`, navigate to the folder on the {abbr}`HPC (i.e. aqua)` where you want to put the files, and then you can drag and drop the files from your local machine (in the right-hand pane) to the folder where you want them (in the left-hand pane).

```{image} attachments/image-20231101-005734.png
:alt: Image showing WinSCP Server window
:width: 800px
:align: center
```

:::

:::{dropdown} Mac or Linux
(on-a-mac-or-linux-machine)=

## On a Mac or Linux machine

If you are using a Mac/Linux computer you can use scp/sftp on the terminal.

(scp)=

### scp

scp is a passive method of transferring files that is used externally from the {abbr}`HPC (i.e. aqua)` (i.e. without logging into the {abbr}`HPC (i.e. aqua)`).

In general, to transfer files using scp, you would open up a command line or terminal window, and at the prompt type something like this (replacing the `/path/to/source/location/file1` and `/path/to/destination/location/` with your appropriate paths):

```{code} bash
:linenos:
:emphasize-lines: 1
scp /path/to/source/location/file1 /path/to/destination/location/
```

So to copy files onto the {abbr}`HPC (i.e. aqua)` using `scp`, replace the `/path/to/destination/location/` with the below text, where `<username>` is substituted by your own QUT username, such as n12234567 or a staff userid:

```{code} bash
:linenos:
:emphasize-lines: 1
scp /path/to/source/location/file1 <username>@aqua.qut.edu.au:/path/to/destination/location/
```

(sftp)=

### sftp

sftp is an interactive method of transferring files where you establish a connection to the HPC.

So to transfer files using `sftp`, open up a command line or terminal window, change directory to the folder where you want to copy a file/folder from, and establish an SFTP connection to aqua at the prompt, type the commands below (where `<username>` is substituted by your own QUT username, such as n12234567 or a staff userid; and `/path/to/source/location/on/local/machine` is substituted by the path where the file is located on your local machine):

```{code} bash
:linenos:
:emphasize-lines: 1,2
cd /path/to/source/location/on/local/machine
sftp <username>@aqua.qut.edu.au
```

You should then have a command prompt similar to the one below:

```
sftp>
```

You are then in your home directory on aqua, so you can change directory to the folder where you want to copy a file/folder to and copy the files/folders to that folder on aqua, by using the `put` command:

```{code} bash
:linenos:
:emphasize-lines: 1,2
cd /path/to/destination/location/on/aqua/
put file1
```

Once you’ve finished using sftp then you can close the interactive session by typing:

```{code} bash
:linenos:
:emphasize-lines: 1
exit
```

If you want to copy files from a folder on aqua to a folder on your local machine use `get` instead:

```{code} bash
:linenos:
:emphasize-lines: 1,2,3,4,5
cd /path/to/destination/location/on/local/machine/
sftp <username>@aqua.qut.edu.au
sftp> cd /path/to/source/location/on/aqua/
sftp> get file2
exit
```

To copy folders instead of files, use the -r parameter:

```{code} bash
:linenos:
:emphasize-lines: 1
get -r folder1
```

:::
[Back to the top](#transferring-files-heading-target)
***

(rsync)=

# rsync

You can use `rsync` if you want to transfer files on the command line (i.e. from /home/ folder to /work/ folder on the {abbr}`HPC (i.e. aqua)`; from another data repository to the {abbr}`HPC (i.e. aqua)` etc).

It can be faster than `scp` for transferring files, especially when syncing large directories or when dealing with files that have already been partially transferred or exist on the destination.

It is often used to do incremental backups as it only transfers the differences between source and destination files, which significantly reduces the amount of data transferred, making it efficient for syncing large files or directories.

You can also do a dry-run prior to actually transferring the files, which will not make any changes to the files and will show the output of the command, if the output shows exactly the same as you want to do then you can remove the `--dry-run` option from your command and run on the terminal. An example command would be:

```{code} bash
:linenos:
:emphasize-lines: 1
rsync -av --dry-run SOURCE DESTINATION
```

Some common options include:

* `-v` verbose output, displaying detailed information about the transfer.

* `-r` copies data recursively (but doesn’t preserve timestamps and permission while transferring data).

* `-a` archive mode, which allows copying files recursively and it also preserves symbolic links, file permissions, user & group ownerships, and timestamps.

* `-z` compress files during transfer to reduce network usage.

* `-h` human-readable, output numbers in a human-readable format.

* `-P` show progress during the transfer.

* `SOURCE` specifies the source file(s) or directory to be transferred, which can be a local or a remote location.

* `DESTINATION` specifies the destination path where the files or directories will be copied. Similar to the source, it can be a local path or a remote location.

* `-R` preserves the full path - if you want part of the path but not all, then use /./ where you want to break the path:

```{code} bash
:linenos:
:emphasize-lines: 1
rsync -R /work/test1/./project1/folder1/ /home/test2/
```

This will copy the files keeping the lower level folder structure: `/home/test2/project1/folder1/`

[Back to the top](#transferring-files-heading-target)
***
(curl-or-wget-on-the-server)=

# curl or wget on the server

It is possible to download files directly on the {abbr}`HPC (i.e. aqua)` using tools like curl and wget.

Say we wanted to download this file from a website that uses ftp:

`ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR206/072/SRR20622172/SRR20622172.fastq.gz`

we could use the `wget` command (note, it will download the file into the folder you are currently in when you run this command):

```{code} bash
:linenos:
:emphasize-lines: 1
wget -nc ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR206/072/SRR20622172/SRR20622172.fastq.gz
```
or we could use the `curl` command (note, it will download the file into the folder you are currently in when you run this command):

```{code} bash
:linenos:
:emphasize-lines: 1
curl -O ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR206/072/SRR20622172/SRR20622172.fastq.gz
```


If you are transferring a number of files or very large files, there are a couple of strategies:
* you could use a PBS batch script on the HPC;
* you could use a piece of software like `pyega` on an {abbr}`rVDI (Research Virtual Workstation)`, instructions on how to do that are [located here](../../Data_transfer/data-how-to-download-data-from-the-european-genome-phenome-archive-ega-using-pyega.md); 
* you could use a tool like `sra-tools` if you need to download a lot of data from the National Center for Biotechnology Information (NCBI), instructions on how to do that are [located here](../../Data_transfer/data-how-to-download-data-using-module-load-sra-tools.md);
* or you could use one of the data transfer nodes **eresdtn01** and **eresdtn02**.

(when-should-i-use-eresdtn01-or-eresdtn02-to-transfer-files-to-the-hpc)=

# When should I use eresdtn01 or eresdtn02 to transfer files to the HPC?

If you are transferring large files or a lot of them, then it's best not to clog up the head node (i.e. aqua) where everyone submits jobs, as this will interfere with every other user of the {abbr}`HPC (i.e. aqua)`. It is best to do this on the data transfer nodes `eresdtn01` or `eresdtn02`. To do this, you can login to them just like you do to aqua, either via PuTTY:

```{image} attachments/putty_eresdtn01.png
:alt: Image showing PuTTY login window with eresdtn01
:width: 400px
:align: center
```
or via ssh in the `CMD PROMPT` or `terminal` window:

```{code} bash
:linenos:
:emphasize-lines: 1
ssh <username>@eresdtn01.qut.edu.au
```

Then you can change directory to your home folder (or wherever you want to transfer the files to/from) and do the rsync/curl/wget command above.

To log out of `eresdtn01` or `eresdtn02`, type:

```{code} bash
:linenos:
:emphasize-lines: 1
exit
```

(tmux)=
## Tmux
When downloading large files, it is good idea to start a <wiki:Tmux> session first. `Tmux` allows you to disconnect from the server and keep your downloads running.

To start `Tmux`, type:
```{code} bash
:linenos:
:emphasize-lines: 1
tmux
```

To disconnect and leave your download running, press and hold {kbd}`Ctrl` then press {kbd}`B`, let go and press {kbd}`D`

To resume a detached `Tmux` session, type:
```{code} bash
:linenos:
:emphasize-lines: 1
tmux attach
```
To finish using `Tmux`, exit the shell normally. 

To get more information about using Tmux, please see the [Tmux Cheat Sheet & Quick Reference](https://tmuxcheatsheet.com/)


***
[Back to the top](#transferring-files-heading-target)
***

**For further help contact eResearch** \
Submit a ticket: [http://qut.to/eresearch-support](http://qut.to/eresearch-support) \
Email us: eresearch@qut.edu.au \
Call us: 07 3138 8899

