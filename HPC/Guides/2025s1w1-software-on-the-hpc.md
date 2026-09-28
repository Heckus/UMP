---
title: Software on the HPC
date: 2025-02-06
subject: tutorial
exports:
  - format: docx
---
(modules-training-heading-target)=
## Modules

The HPC is used by many people with diverse software requirements. You might require Python 3.11.3 for your script, and your colleague requires Python 3.13.5 for their script. How do we install both on the HPC?

Software Modules are used on the HPC to solve this issue of installing conflicting software. A software module is a partially installed version of the software. When you want to use this software, you need to activate it so it is available to you. Activation “completes” the install in a temporary manner. When no longer required, the module can be removed.

To see a list of modules on the system use the command:

```{code} bash
:linenos:
:emphasize-lines: 1
module spider
```

This prints out a list of all the software on the HPC

You can limit the list adding a name (or partial name) to the command:

```{code} bash
:linenos:
:emphasize-lines: 1
module spider Python
```

We now see all the python modules and versions available to us.

Lets find and load python 3.11.3

```{code} bash
:linenos:
:emphasize-lines: 1,2,3,4,5,6,7,8
which python
{system python}
module spider python
{module information about any modules that include python in their name}
module load GCCcore/12.3.0
module load Python/3.11.3
which python
{module python}
```

We can see which modules are currently active by using:

```{code} bash
:linenos:
:emphasize-lines: 1
module list
```

We can see python loaded other dependent modules.

To deactivate a module we use the unload command

```{code} bash
:linenos:
:emphasize-lines: 1
module unload Python
```

Python 3.11.3 is no longer available

```{code} bash
:linenos:
:emphasize-lines: 1,2
which python
{system python}
```
However, the dependencies loaded for Python/3.11.3 are still loaded.

To remove all modules, you can unload each one at at time, or use the purge command to remove all of them:

```{code} bash
:linenos:
:emphasize-lines: 1,2,3
module list
module purge
module list
```

A good practice to get into is to `module purge` after loading different modules, if you're testing your analysis in an interactive job. This is because the dependencies of modules include the toolchain that it is installed with, and if you try to `module spider` another module without unloading that toolchain you will only see other modules that are compatible with that earlier toolchain.

## Module conflicts can occur when loading modules.

You cannot load two different versions of the same package:

```{code} bash
:linenos:
:emphasize-lines: 1,2,3,4,5,6,7,8,9,10,11
module spider R
module load GCC/13.2.0
# Load R version 4.3.3
module load R/4.3.3
R --version

# Load R version 4.4.1
module load R/4.4.1

The following have been reloaded with a version change:
  1) R/4.3.3 => R/4.4.1
```

### Installing Software

### Conda:

Conda is a package manager and can be used to install packages to your home folder.

Either you can load a conda module or download the miniconda package.

You use different environments to separate different versions of packages.

The conda modules can be displayed with:

```{code} bash
:linenos:
:emphasize-lines: 1
module spider anaconda
```

When you use a conda module, it is a good idea to run the `conda init` command to update your shell files so conda functions correctly.

Alternatively, you can install miniconda to your home folder by following the [instructions](https://docs.anaconda.com/miniconda/miniconda-install/). Be sure to choose 'yes' at the update shell question.

Once you have run `conda init`, or installed Minconda, you should logout of the HPC and log back in again to activate the shell changes.

(using-singularity-or-apptainer)=
### Using Singularity or Apptainer

Singularity runs software containers. A container is a packaged collection of software. The advantage of using a container is it is portable, and runs without installation. There is more information about [Singularity (and Apptainer) here](../../../Aqua/Specific_software/multipurpose/multipurpose/how-to-use-software-containers.md)

### By Hand

It is possible to download application source code, compile, and install to your home folder.

This is an **advanced** topic!

Start by module loading the compiler and tool chain you need to build the software…but remember to do this within an interactive job appropriate for the software (i.e. if it will run on a GPU, use a GPU interactive job).

***
Before you move on to the next section, try these `QUIZ questions` to test your knowledge of material on this page:

:::{attention}QUIZ Question 12
How would you find out what versions of the Python module are available on the HPC? \
(Multiple choices are correct)*
1. Use the `module spider` command and scroll through them one by one
2. Use the `module spider python` command
3. Use the `which python` command
4. Use the `module list` command

:::{attention} Show me the Solution
:class: dropdown
1. Technically correct, although scrolling through all the modules after using the `module spider` command would be the least efficient way to do this
2. Correct, using the `module spider python` command is the fastest way to find out what versions of Python are available on the HPC
3. Incorrect, the `which python` command only tells you about which version is already loaded on the HPC
4. Incorrect, the `module list` command only shows you what modules you have already loaded
:::



* * *
[Back to the top](#modules-training-heading-target)
* * *

**For further help contact eResearch** \
Submit a ticket: [http://qut.to/eresearch-support](http://qut.to/eresearch-support) \
Email us: eresearch@qut.edu.au \
Call us: 07 3138 8899
