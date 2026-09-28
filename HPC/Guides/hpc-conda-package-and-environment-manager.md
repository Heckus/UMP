---
title: Conda package and environment manager
date: 2026-09-08
---
(conda-package-and-environment-manager-heading-target)=

****Conda is a powerful package manager and environment manager that you use on the command line, that will allow you to manage multiple pieces of software with different versions and dependencies that might clash.****

:::{admonition} Prerequisites
:class: tip
You will need to be logged in to the HPC to run these commands \
You will need to have at least one Data Management Plan with an RPID
:::

(why-use-conda)=
# Why use Conda?

When you run lots of analyses you might run into the problem that you have many different pieces of software that have dependencies that clash with other pieces of software or you might have specific versions of software required to run different scripts that can’t be installed at the same time. Conda allows you to set up different environments for different sets of software/versions of software that are completely separate from each other. You activate and deactivate each environment as needed to run whichever script that requires it.

## There are a couple of ways to use conda on the HPC:

(1.-instructions-on-how-to-install-conda-are-on-this-page)=
### 1. Install conda yourself
Instructions on how to install conda are on the [Accessing available software page](#install-conda)

You should only need to do this once and then conda will be available for you to use on the HPC from then on.

(2.-or-miniconda-is-loaded-via-the-module-command)=
### 2. OR Miniconda is loaded via the `module` command

Investigate the `miniconda` module:

```{code} bash
:linenos:
:emphasize-lines: 1
module spider miniconda
```

And `module load` it and then run `conda init`:
```{code} bash
:linenos:
:emphasize-lines: 1,2
module load Miniconda3/24.9.2-0
conda init
```

(basic-conda-commands)=
# Basic conda commands

Verify `conda` is installed and check the version number:

```{code} bash
:linenos:
:emphasize-lines: 1
conda info
```

Update `conda` to the current version:

```{code} bash
:linenos:
:emphasize-lines: 1
conda update conda
```

Install a package included in Anaconda (replace `<PACKAGENAME>` with the name of the package):

```{code} bash
:linenos:
:emphasize-lines: 1
conda install <PACKAGENAME>
```

Update any installed program (replace `<PACKAGENAME>` with the name of the package):

```{code} bash
:linenos:
:emphasize-lines: 1
conda update <PACKAGENAME>
```

(using-environments)=
# Using environments

:::{note} Creating a conda environment for use with a GPU 
When you create a conda environment, if you need a GPU to run the analysis then you need to build it on a GPU. The same is true for `A100 vs H100 GPUs`, if the analysis will run on an `A100` you need to build the conda environment on an `A100`, and vice versa. We recommend starting an Interactive job on the correct type of GPU and creating the conda environment there, although you need to check whether the packages you want to install have a GPU-specific version, i.e. installing `pytorch-gpu` instead of `pytorch`. Often you can still use this `GPU-created` conda environment on a CPU but the reverse is not true: if you create it on a CPU you won't be able to later utilise a GPU if you request one.
:::

Create a new environment named py35, then install Python 3.5:

```{code} bash
:linenos:
:emphasize-lines: 1
conda create --name py35 python=3.5
```

Activate the new environment to use it (you can use either `source activate` OR `conda activate`). You need to do this before installing packages:

```{code} bash
:linenos:
:emphasize-lines: 1,2
source activate py35
conda activate py35
```

Get a list of all my environments (active environment is shown with \*):

```{code} bash
:linenos:
:emphasize-lines: 1
conda env list
```

Make an exact copy of an environment:

```{code} bash
:linenos:
:emphasize-lines: 1
conda create --clone py35 --name py35-2
```

List all packages and versions installed in active environment:

```{code} bash
:linenos:
:emphasize-lines: 1
conda list
```

List installed packages with source info:

```{code} bash
:linenos:
:emphasize-lines: 1
conda list --show-channel-urls
```

List the history of each change to the current environment:

```{code} bash
:linenos:
:emphasize-lines: 1
conda list --revisions
```

List the history of each change to environment by name (py35):

```{code} bash
:linenos:
:emphasize-lines: 1
conda list -n py35 --revisions
```

Restore environment (py35) to a previous revision:

```{code} bash
:linenos:
:emphasize-lines: 1
conda install -n py35 --revision 2
```

Save your environment to a text file:

```{code} bash
:linenos:
:emphasize-lines: 1
conda list --explicit > bio-env.txt
```

Delete an environment and everything in it:

```{code} bash
:linenos:
:emphasize-lines: 1
conda env remove --name bio-env
```

Deactivate the current environment:

```{code} bash
:linenos:
:emphasize-lines: 1
conda deactivate
```

:::{note}
We don't recommend deactivating your conda environment at the end of your PBS batch job script after the line that runs your analysis as then it will be the last command in your job, which is what the `Exit_status` of the job evaluates. For example, if your analysis has an error (should have `Exit_status` != `0`) but the job script then goes on to deactivate your conda environment, your job's `Exit_status` = `0` whereas you want it reflect the fact your analysis actually failed.
:::


Create an environment from a text file:

```{code} bash
:linenos:
:emphasize-lines: 1
conda env create --file bio-env.txt --name new_env
```

Stack commands: create a new environment, name it bio-env, and install the biopython package in one line:

```{code} bash
:linenos:
:emphasize-lines: 1
conda create --name bio-env biopython
```

(managing-multiple-versions-of-python)=
## Managing multiple versions of Python

Install different versions of Python in a new environment named py34:

```{code} bash
:linenos:
:emphasize-lines: 1
conda create --name py34 python=3.4
```

Switch to a new environment that has a different version of Python:

```{code} bash
:linenos:
:emphasize-lines: 1
conda activate py34
```

Show the locations of all versions of `Python` that are currently in the path (NOTE, the first version of Python in the list will be executed):

```{code} bash
:linenos:
:emphasize-lines: 1
which -a python
```

Show version information for the current active `Python`:

```{code} bash
:linenos:
:emphasize-lines: 1
python --version
```

:::{important}
Note, if you find that the `python` version in your base (or another) environment supercedes the new version of `python` you install in your new conda environment, you may need to deactivate your conda environment multiple times before creating your new conda environment.
:::

(exporting-environments)=
## Exporting environments

Recommendation: Name the export file `ENV`. Environment name will be preserved:

Export your environment to be cross-platform compatible:

```{code} bash
:linenos:
:emphasize-lines: 1
conda env export --from-history > ENV.yml
```

Export an environment to be platform-, package- and channel-specific:

```{code} bash
:linenos:
:emphasize-lines: 1
conda list --explicit > ENV.yml
```
(importing-environments)=
## Importing environments

Tip: When importing an environment, conda resolves platform and package specifics.

From a .yml file (replace `<ENVNAME>` with the name you want to give the new conda environment):

```{code} bash
:linenos:
:emphasize-lines: 1
conda env create -n <ENVNAME> --file ENV.yml
```

From a .txt file (replace `<ENVNAME>` with the name you want to give the new conda environment):

```{code} bash
:linenos:
:emphasize-lines: 1
conda create -n <ENVNAME> --file ENV.txt
```
(conda-packages)=
# Conda packages
[See a list of all packages in Anaconda](https://docs.anaconda.com/free/anaconda/reference/packages/pkg-docs/)

Use `conda` to search for a package (replace `<PACKAGENAME>` with the name of the package):

```{code} bash
:linenos:
:emphasize-lines: 1
conda search <PACKAGENAME>
```
(installing-and-updating-packages)=
## Installing and updating packages

Install a new package (Jupyter Notebook) in the active environment:

```{code} bash
:linenos:
:emphasize-lines: 1
conda install jupyter
```

Run an install package (Jupyter Notebook):

```{code} bash
:linenos:
:emphasize-lines: 1
jupyter-notebook
```

Install a new package (e.g. toolz) in a different environment (e.g. bio-env):

```{code} bash
:linenos:
:emphasize-lines: 1
conda install --name bio-env toolz
```

Update a package in the current environment (e.g. scikit-learn):

```{code} bash
:linenos:
:emphasize-lines: 1
conda update scikit-learn
```

Update all packages

```{code} bash
:linenos:
:emphasize-lines: 1
conda update --all
```

Install a package directly from `PyPI` into the current active environment using pip:

```{code} bash
:linenos:
:emphasize-lines: 1
python -m pip install boltons
```

Remove one or more packages (e.g. toolz, boltons) from a specific environment (e.g. bio-env):

```{code} bash
:linenos:
:emphasize-lines: 1
conda remove --name bio-env toolz boltons
```

Uninstall package (e.g. boltons):

```{code} bash
:linenos:
:emphasize-lines: 1
conda uninstall boltons
```
(channels)=
# Channels

Show your `conda` configuration's current state:

```{code} bash
:linenos:
:emphasize-lines: 1
conda config --show channels
```

View config file locations:

```{code} bash
:linenos:
:emphasize-lines: 1
conda config --show-sources
```

Install a package (e.g. boltons) from a specific channel (e.g. conda-forge):

```{code} bash
:linenos:
:emphasize-lines: 1
conda install --channel conda-forge boltons
```

Install a package (e.g. boltons) from a specific channel (e.g. conda-forge):

```{code} bash
:linenos:
:emphasize-lines: 1
conda install conda-forge::boltons
```

View channel sources:

```{code} bash
:linenos:
:emphasize-lines: 1
conda config --show-sources
```

Add channel(s): priority decreases from left to right:

```{code} bash
:linenos:
:emphasize-lines: 1
conda config --add channels conda-forge,bioconda
```

Set default channel for package fetching (targets first channel in channel sources):

```{code} bash
:linenos:
:emphasize-lines: 1
conda config --set channel_priority strict
```

If you want to override this strict priority of channels, then change using this:

```{code} bash
:linenos:
:emphasize-lines: 1
conda config --set channel_priority true
```

(specifying-version-numbers)=
# Specifying version numbers

Ways to specify a package version number for use with conda create or conda install commands, and in meta.yaml files:

| **Constraint type** | **Specification** | **Result** |
| --- | --- | --- |
| Fuzzy | numpy=1.11 | 1.11.0, 1.11.1, 1.11.2, 1.11.18 etc |
| Exact | numpy==1.11 | 1.11.0 |
| Greater than or equal to | “numpy>=1.11” | 1.11.0 or higher |
| OR  | “numpy=1.11.1\|1.11.3” | 1.11.0, 1.11.3 |
| AND | “numpy>=1.8,<2” | 1.8, 1.9, not 2.0 |

:::{note}
Quotation marks must be used when your specification contains spaces or any of these characters: > < | \*
:::
(additional-hints)=
# Additional hints

Getting help for any command (replace `<COMMAND>` with the name of the command you want help with):

```{code} bash
:linenos:
:emphasize-lines: 1
conda <COMMAND> --help
```

Get info for any package (replace `<PACKAGENAME>` with the name of the package):

```{code} bash
:linenos:
:emphasize-lines: 1
conda search <PACKAGENAME> --info
```

Run commands without user prompt, for example if you want to install multiple packages (replace `<COMMAND>` with the name of the command, `<ARG>` with any argument that command needs, and `<PKG1>` and `<PKG2>` with the package names you want to install):

```{code} bash
:linenos:
:emphasize-lines: 1,2
conda <COMMAND> <ARG> --yes
conda install <PKG1> <PKG2> --yes
```

Remove all unused files:

```{code} bash
:linenos:
:emphasize-lines: 1
conda clean --all
```

Examine conda configuration:

```{code} bash
:linenos:
:emphasize-lines: 1
conda config --show
```

If you are trying to install multiple packages with dependencies that may conflict, you can use conda-tree to see the tree of dependencies for a particular library (e.g. for `numpy`):

```{code} bash
:linenos:
:emphasize-lines: 1,2,3
conda install -c conda-forge conda-tree
conda-tree whoneeds -t numpy
```
(an-example-of-setting-up-a-complex-conda-environment)=
# An example of setting up a complex conda environment
1. Create an `environment.yml` file with the list of conda packages you need to install. You can list the channels that these packages are in, all the package and their dependencies (including a specific version and build), pip and any pip packages you need to install, and a license file for the software:
```{code} bash
:linenos:
:emphasize-lines: 1,2,10,12,26,27
name: STAN
channels:
  - conda-forge
  - bioconda
  - defaults
  - anaconda
  - gurobi
  - https://repo.anaconda.com/pkgs/main
  - https://repo.anaconda.com/pkgs/r
dependencies:
  - stanio
  - "gurobi 11.0.3 py311_0"
  - pandas
  - scipy
  - numpy
  - matplotlib
  - time
  - arviz
  - pypickle
  - cmdstanpy
  - pygad
  - openpyxl
  - pip
  - pip:
    - gurobipy
variables:
  GRB_LICENSE_FILE: /pkg/rhel94/AuthenticAMD-25/software/Gurobi/11.0.3-GCCcore-12.3.0/gurobi.lic
```

2. Then run your PBS script to create the conda environment using this `environment.yml` file (remember to replace the `ABCDEF1234` parameter in line 4 with the appropriate {abbr}`RPID (Research Project ID)` that you have access to):

```{code} bash
:linenos:
:emphasize-lines: 9,11
#!/bin/bash -l
#PBS -l select=1:ncpus=12:mem=185gb:cpu_id=any
#PBS -l walltime=10:00:00
#PBS -P ABCDEF1234
#PBS -m abe

cd $PBS_O_WORKDIR

conda env create -f environment.yml -n STAN

conda activate STAN

python gurobi_hpc.py $var1 $var2
```

***
[Back to the top](#conda-package-and-environment-manager-heading-target)
***

:::{admonition} Resources used to write this page
:class: hint
*   [https://docs.conda.io/projects/conda/en/4.6.0/\_downloads/52a95608c49671267e40c689e0bc00ca/conda-cheatsheet.pdf](https://docs.conda.io/projects/conda/en/4.6.0/_downloads/52a95608c49671267e40c689e0bc00ca/conda-cheatsheet.pdf)
    
*   [https://docs.conda.io/projects/conda/en/stable/user-guide/cheatsheet.html](https://docs.conda.io/projects/conda/en/stable/user-guide/cheatsheet.html)
:::
***

**For further help contact eResearch** \
Submit a ticket: [http://qut.to/eresearch-support](http://qut.to/eresearch-support) \
Email us: eresearch@qut.edu.au \
Call us: 07 3138 8899