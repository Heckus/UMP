---
title: Using Graphical Processing Units (GPUs)
date: 2026-09-08
---
(using-gpus-heading-target)=

****Converting an analysis to use GPUs is not necessarily a simple process and only specific analyses can make use of GPUs. In general, GPUs can be used to speed up certain types of computations. However, GPU performance varies widely between different GPU devices. 
GPU’s have more cores than CPUs and hence when it comes to parallel computing of data, GPUs perform exceptionally better than CPUs even though GPUs have lower clock speed and lack several core management features as compared to the CPU.****

:::{admonition} Prerequisites
:class: tip
You will need to be logged in to the HPC to run these commands \
You will need to have experience running your PBS job scripts on CPUs on the HPC \
You will need to have at least one Data Management Plan with an RPID
:::

In order to quantify the performance of a GPU, three tests are used:
*   How quickly can data be sent to the GPU or read back from it?     
*   How fast can the GPU kernel read and write data?   
*   How fast can the GPU perform computations?

***
(gpus-with-python)=
## GPUs with Python

Running a `Python` script on GPUs can prove to be comparatively faster than CPUs, however, it must be noted that for processing a data set with GPUs, the data will first be transferred to the GPU’s memory which may require additional time so if your data set is small then CPUs may perform better than GPUs. To get used to running `Python` scripts with GPUs, here are some basic instructions, where you can test the speed of `Python` on GPUs using an example script:
(run-a-python-test-script-as-an-interactive-job)=
### Run a Python test script as an interactive job
If you copy and paste this command, remember to replace the `ABCDEF1234` parameter with the appropriate {abbr}`RPID (Research Project ID)` that you have access to:
```{code} bash
:linenos:
:emphasize-lines: 1
qsub -I -l select=1:ncpus=1:ngpus=1:mem=16gb -l walltime=02:00:00 -P ABCDEF1234
```

Then load the required `Anaconda` module and create a conda environment (you will only need to run the `conda init` line once because it adds some code to one of your default files: `~/.bashrc`):

```{code} bash
:linenos:
:emphasize-lines: 1,2,3,4,5,6
module load Anaconda3/2024.02-1
conda init
conda env create -n python_gpu --file environment_gpu.yml
conda activate python_gpu
```
Here is what is specified in this `environment_gpu.yml` file:
```{code} bash
:linenos:
:emphasize-lines: 1,2,3,4,5,6,7,8,9
name: python_gpu
channels:
  - conda-forge
dependencies:
  - python>=3.9,<3.12
  - pip==25.1.1
  - cudatoolkit==11.8.0
  - pip:
    - -r requirements_gpu.txt
```
And here is what is specified in the `requirements_gpu.txt` file:
```{code} bash
:linenos:
:emphasize-lines: 1,2,3
numba==0.61.2
numpy==1.25.2
torch
```
Once you have activated the `python_gpu` conda environment, then you can check that python detects your GPU with this command:
```{code} bash
:linenos:
:emphasize-lines: 1,2,3
python
import torch
torch.device("cuda" if torch.cuda.is_available() else "cpu")
```
If it returns this, then python is detecting your GPU:
```{code} bash
device(type='cuda')
```
***
The test code below will use the numba.jit decorator for the function we want to compute over the GPU. The decorator has several parameters but we will work with only the target parameter. Target tells the jit to compile codes for which source(“CPU” or “Cuda”). “Cuda” corresponds to GPU. However, if the CPU is passed as an argument then the jit tries to optimize the code to run faster on CPU and improves the speed too. 

Save this script as `python_gpu.py`:

```{code} python
:linenos:
:emphasize-lines: 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26
from numba import jit, cuda
import numpy as np
# to measure exec time
from timeit import default_timer as timer 

# normal function to run on cpu
def func(a):							 
	for i in range(10000000):
		a[i]+= 1	

# function optimized to run on gpu 
@jit					 
def func2(a):
	for i in range(10000000):
		a[i]+= 1
if __name__=="__main__":
	n = 10000000						
	a = np.ones(n, dtype = np.float64)
	
	start = timer()
	func(a)
	print("without GPU:", timer()-start) 
	
	start = timer()
	func2(a)
	print("with GPU:", timer()-start)
```

Then you can run it like this:

```{code} bash
:linenos:
:emphasize-lines: 1
python python_gpu.py
```

You should get an output that looks something like this:

```{code} bash
> without GPU: 2.4089387280400842
> with GPU: 7.021396802039817
```
This shows you that for a simple action like this counting function, using a CPU may actually be faster than using a GPU. Which is a good check to do, so you don't waste time with your job sitting in a GPU queue (often access to the GPUs is very competitive) when it can easily run on a CPU.

If you replace the functions in this `python_gpu.py` script with the functions that you want to test, you are hoping for an improvement in the time taken from CPU to GPU, like this:

```{code} bash
> without GPU: 7.91824261425063
> with GPU: 0.50043626409024
```

:::{note}
If you want to modify this `python_gpu.py` script to test whether your python script works faster under CPU or GPU, special care should be taken when the function which is written under the jit attempts to call any other function. That function should also be optimized with jit or else the jit may produce even slower codes.
:::


***
[Back to the top](#using-gpus-heading-target)
***
:::{admonition} Resources used to write this page
:class: hint
*   [https://www.geeksforgeeks.org/running-python-script-on-gpu/](https://www.geeksforgeeks.org/running-python-script-on-gpu/) 
*   [https://au.mathworks.com/help/parallel-computing/benchmarking-independent-jobs-on-the-cluster.html](https://au.mathworks.com/help/parallel-computing/benchmarking-independent-jobs-on-the-cluster.html)
:::
* * *

**For further help contact eResearch** \
Submit a ticket: [http://qut.to/eresearch-support](http://qut.to/eresearch-support) \
Email us: eresearch@qut.edu.au \
Call us: 07 3138 8899