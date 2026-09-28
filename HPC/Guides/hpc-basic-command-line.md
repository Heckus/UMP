---
title: Basic commands that are useful
date: 2024-11-19
---
(basic-command-line-heading-target)=

****The QUT HPC is a Linux cluster, which is a free and open-source version of UNIX. As the mac terminal is UNIX-like, it is often easier to work between your mac desktop/laptop and the HPC than between a windows desktop/laptop and the HPC.****

:::{admonition} Prerequisites
:class: tip
You will need to be logged in to the HPC to do these activities \
OR \
You can practice these commands on a mac or linux terminal
:::

# Useful commands on the HPC
There are a lot of useful scripts to help you monitor the HPC and your job(s), and we have made these available to you. Here are some of them:

```{code} bash
:linenos:
:emphasize-lines: 1,2,3,4,5,6,7,8
pbsnodeinfo # Shows the current usage of each node
qpeek <JOBID> # Shows you the standard output of the <JOBID> as its being written for a currently running job
qpeek -e <JOBID> # Shows you the standard error of the <JOBID> as its being written for a currently running job
#(note: some software writes important info to the standard error file rather than the standard output file)

print_queues.sh # Tells you about the max limits for each queue
time_until_outage.sh # Tells you the time until the next scheduled maintenance
qjobs # Tells you about your current jobs
```



(linux-terminal-commands)=
# Linux terminal commands

(basic-linux-commands)=
## Basic Linux Commands

Here is a curated list of the most common Linux commands you will use on the HPC. This list is by no means extensive, but these commands will allow you to navigate the HPC as well as create, destroy, and manipulate files and directories.

(get-info-about-commands)=
### Get info about commands

Display online manual pages. Most Linux commands have a manual page with detailed instructions on use. Replace `<command name>` below with the command you would like information on.

```{code} bash
:linenos:
:emphasize-lines: 1
man <command name>
```
(navigating-the-directory-structure)=
### Navigating the directory structure

On a Linux system, directories are containers for files and objects. The `pwd` command lists the present working directory. This is the “where am I?” command. So when you first login to the HPC, you will be in your home folder, which you can see if you use `pwd`.

```{code} bash
:linenos:
:emphasize-lines: 1
pwd
```
(ls)=
### ls

The `ls` command will list files in the current directory. If you run this command in your home directory, at a minimum you will see that there is another directory called `public_html`, which is an automatically created *subdirectory* of your home folder. 

```{code} bash
:linenos:
:emphasize-lines: 1
ls
```

If you would like to see if a directory contains a specific file, you can pass the directory path and file name to `ls` as an argument

```{code} bash
:linenos:
:emphasize-lines: 1
ls a.out 
```

Setting the `-l` flag will display files along with their permissions and ownership.

```{code} bash
:linenos:
:emphasize-lines: 1
ls -l
```
(cd)=
### cd

The `cd` command changes into a directory.

```{code} bash
:linenos:
:emphasize-lines: 1
cd public_html
```

And public\_html is itself a subdirectory of home (home is otherwise known as ~), which is a subdirectory of the root directory (/). Thus, the directories form a downward-facing tree with all directories stemming from the root directory. You can move one level up in the tree by typing `cd ..`

```{code} bash
:linenos:
:emphasize-lines: 1
cd .. 
```

And you can navigate using either relative or absolute paths. That is, you can enter directory paths relative to your current location, or you can enter the entire path starting with the home (~) directory.

```{code} bash
:linenos:
:emphasize-lines: 1
cd ~/public_html/
```

Lastly, if you ever get lost you can use the tilde (`~`) to return to your HOME directory. You can also return there by just using `cd`

```{code} bash
:linenos:
:emphasize-lines: 1
cd ~
```

(mkdir)=
### mkdir

Create a new directory with `mkdir` and adding the `-p` option creates all parental folders (if they’re not already present). This command allows you to make multiple folder levels at the same time (if the `testdir` folder is already there, it will just make the `test` folder within it).

```{code} bash
:linenos:
:emphasize-lines: 1
mkdir -p testdir/test
```
(rm)=
### rm

Remove files and directories. 

```{warning}
Be careful with the `rm` command as there is no undoing this command.
```

```{code} bash
:linenos:
:emphasize-lines: 1
rm testfile
```

If you would like to remove a directory and all of its contents, use the following command:

```{code} bash
:linenos:
:emphasize-lines: 1
rm -ri testdir
```

The `-r` flag specifies to remove files/directories recursively. `-i` specifies to prompt before deleting each file.

If you are confident with the command line and your understanding of file locations you can use the `-f` flag instead of `-i` to force the deletion of all files without prompting:

```{code} bash
:linenos:
:emphasize-lines: 1
rm -rf testdir
```
(rmdir)=
### rmdir

Removes directories. The `rmdir` is a safer approach than using `rm` `-r` as it will only act on empty directories.

```{code} bash
:linenos:
:emphasize-lines: 1
rmdir NextDirectoryDown/
```
(cp)=
### cp

Copy a file to a new location.

In the example below `<sourcefile>` already exists, and `<destinationfile>` may or may not exist and will become a copy of sourcefile.

```{code} bash
:linenos:
:emphasize-lines: 1
cp <sourcefile> <destinationfile>
```

To copy a directory and all of its contents we use the recursive flag `-r`:

```{code} bash
:linenos:
:emphasize-lines: 1
cp -r <sourcedir> <destinationdir>
```

Take note of the order here: source first, destination second. This is the standard order across most `*nix` commands (`*nix` represents ‘UNIX-like operating systems’).

(mv)=
### mv

Move a file to a new location (line 1) or rename it in the same location (line 2).

```{code} bash
:linenos:
:emphasize-lines: 1,2
mv file1 ./destinationdir/
mv file1 file2
```

Unlike `cp`, the `mv` command does not create a second instance of the file or directory.

(cat)=
### cat

Shows you the entire contents of a file (short for conCATenate).

```{code} bash
:linenos:
:emphasize-lines: 1
cat daysofweek.txt
```
(tail)=
### tail

Displays lines from the end of a file. Useful for viewing recent results in an output file. The `-n` flag can be used to specify the number of lines to show (the default without specifying is 10 lines).

```{code} bash
:linenos:
:emphasize-lines: 1
tail -n 3 animals
```

The `-f` flag can be used to tail a file interactively. New additions to the end of the file will be printed on your screen, which is a great way to monitor a log file as its being written.

(head)=
### head

`head` is much like `tail`, except it prints from the top of a file.

```{code} bash
:linenos:
:emphasize-lines: 1
head -n 2 animals
```
(more)=
### more

`more` is like `cat`, except it prints the file one page at a time. The spacebar is used to continue to the next page.

For more advanced linux commands, see the [More Command Line page](../Learning_more/hpc-intermediate-command-line.md)

***
[Back to the top](#basic-command-line-heading-target)
***
:::{admonition} Resources used to write this page
:class: hint
*   [https://www.youtube.com/watch?v=cBokz0LTizk&t=1s](https://www.youtube.com/watch?v=cBokz0LTizk&t=1s)
*   [https://www.youtube.com/watch?v=s3ii48qYBxA](https://www.youtube.com/watch?v=s3ii48qYBxA)
:::
* * *

**For further help contact eResearch** \
Submit a ticket: [http://qut.to/eresearch-support](http://qut.to/eresearch-support) \
Email us: eresearch@qut.edu.au \
Call us: 07 3138 8899

