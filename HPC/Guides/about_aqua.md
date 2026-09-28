---
title: About Aqua
date: 2025-01-10
---
(about-aqua-heading-target)=

****This is a summary of the Aquarius System****
(about-aqua)=
# About Aqua (QUT's supercomputer or HPC)
A <wiki:supercomputer> is a high-performance computing (`HPC`) system designed to process massive amounts of data and perform complex calculations at incredibly fast speeds, far beyond the capabilities of a regular desktop or laptop. They are essential for advancing knowledge and innovation by enabling research that would be impossible or take years to complete on standard machines. Supercomputers are used to solve problems that require vast computing power such as climate modelling, genomics, structural analysis and materials science, epidemiological modelling (virus spreading), and large scale machine learning.
QUT’s centrally funded supercomputer is called `Aqua` or `Aquarius`. Aqua is free for QUT researchers to use.

# Privacy Statement
To help monitor the health, usage, and performance of our system, we generate regular reports that include user activity data. These reports contain usernames and related usage metrics of jobs submitted to the HPC. This information is used solely for internal monitoring and maintenance purposes to ensure our services remain reliable, secure, and effective.
We are committed to protecting your privacy. User data included in these reports is not shared with third parties and is handled in accordance with our data protection and privacy policies.
If you have any questions about how your information is used, please contact us at eresearch@qut.edu.au

# Maintenance
Regular maintenance of the HPC cluster is required to perform updates and implement improvements. To perform maintenance, the system must be taken offline.

HPC maintenance will now occur on the `third Wednesday of each month` commencing 20 August 2025. Outage times will vary. For most maintenance outages we will aim to complete the maintenance on the HPC within a 24hr window `from 8am` each monthly maintenance day but this window will be subject to change depending on each months requirements. Users will be notified via email of a more precise outage window in the weeks prior to the maintenance each month. This change to monthly maintenance should reduce the overall impact of maintenance on users.

## Schedule of planned maintenance days for the next 12 months:
21/01/2026 18/02/2026 18/03/2026 15/04/2026 20/05/2026 17/06/2026 15/07/2026 19/08/2026 16/09/2026 21/10/2026 18/11/2026 16/12/2026

# Emails from eResearch@qut.edu.au
Users of the HPC are automatically added to the {abbr}`HPC users email list (qut.hpc_users@qut.edu.au)` when they are given access to it. eResearch will send emails about outages to this email list regularly (i.e. about `planned maintenance` or when `unexpected outages` occur). However, emails may also be sent directly to individual users about specific jobs (i.e. automatically by the `PBS job scheduler` when a job exceeds it's walltime or by `eResearch staff` if the user has a problematic job running). If users want to set up `Outlook rules` to send all automatic PBS scheduler derived emails to a folder, they should follow these guidelines so that the other types of important emails are not inadvertently missed:
* Make a folder to send them to (labeled `PBS jobs` or similar)
* Make sure its addressed to you specifically (not the email list)
* Includes the word `PBS` in the Subject line

```{image} ./attachments/email_rule.png
:alt: Outlook 
:width: 800px
:align: center
```


(hardware)=
# Hardware
(vendor)=
## Vendor
QUT has partnered with Dell and HPE to build and deploy Aquarius. Dell was selected to supply and support the new CPU and GPU compute components and HPE were selected to supply the highspeed scratch storage.

(aquarius-specifications)=
## Aquarius Specification summary
*  14 nodes, each with a HGX H100 4-`GPU` (56 total), 80GB of VRAM per card, 2 x 400Gbit InfiniBand interconnect 
*  8 nodes, each with a HGX A100 8-`GPU` (retained from previous Lyra system), 40GB VRAM per card
*  50 nodes, with 192 AMD Genoa 9684X `CPU` cores, 1.5TB of Memory and 200GBit InfiniBand interconnect 
*  A `large memory node`, with 192 AMD Genoa 9684X CPU cores, 6TB DDR5 Memory and 2 x 400Gbit InfiniBand interconnect 
*  Almost 1 Petabyte of Weka storage running on HPE Gen5 NVMe Flash on the 400GBit NDR InfiniBand fabric 21 Millions IOPS and 600GB/s capable  
***

| Type of node         | No of nodes | No of CPUs* | No of GPUs* | Memory* |
| :------------------- | :---------: | :---------: | :---------: | :-----: |
| CPU batch            |     49      |     188     |      -      | 1478GB  |
| CPU interactive      |      1      |     376     |      -      | 1478GB  |
| CPU Large Memory     |      1      |     180     |      -      | 6014GB  |
| GPU batch A100       |      7      |     124     |     8^      |  975GB  |
| GPU interactive A100 |      1      |     120     |      3      |  975GB  |
| GPU batch H100       |     13      |     168     |      4      |  974GB  |
| GPU interactive H100 |      1      |     168     |     28      |  974GB  |

`*` - Per node numbers of CPUs/GPUs/memory \
`^` - Most A100 GPUs in the batch queue have 8 GPUs but one has 4 and another has 16

:::{tip}
You can see the specifications of these nodes and how busy each of them are by using the `pbsnodeinfo` command on the HPC
:::

(summary-of-cpu-hardware)=
## Details of CPU hardware
These are the specifications of the CPUs on Aqua:
*  50 nodes of AMD EPYC 9684X (total of 9792 cores): `cpu_id=AMD-25-17` 188 cores and 1447 GB memory are user addressable per node
*  Intel(R) Xeon(R) Platinum 8468 (total of 1344 cores) \*Note: Not available for CPU jobs, GPU nodes only

(summary-of-gpu-hardware)=
## Details of GPU hardware
These are the specifications of the GPUs on Aqua:
*  14 nodes of HGX H100 4-way boards ( 56 cards ): `gpu_id=H100` 176 cores hyper threading enabled and 942 GB of memory are user addressable per node
*  8 nodes of HGX A100 8-way boards ( 48 cards ): `gpu_id=A100` 120 cores and 1004GB of memory are user addressable per node
*  MI100 ( 1 card ): `gpu_id=MI100`, MI200 ( 2 cards ): `gpu_id=MI200` 120 cores and 1004GB of memory are user addressable. ****Note: neither the MI100 nor the MI200 are currently available on Aqua.****

(summary-of-large-memory-hardware)=
## Details of Large Memory hardware
* 1 node with 6TB of DDR5 Memory and 192 CPU cores: 180 cpus and 5982 GB of memory are user addressable per node

Jobs will be automatically scheduled on this node if memory larger than 1.5TB is requested.

***
# Including HPC in proposals
Approval from eResearch is not required to include general use of HPC resources in proposals. The following specifications can be used for in-kind costing:

## Processing
* $0.02 per core, with 8GB RAM, per hour

## GPU
* $2.65 per GPU, per hour

## Large Memory Node
* $0.05 per core, with 32GB memory, per hour

## Storage
* $475 per TB data stored, per year

If you require dedicated resources, log a [ticket](http://qut.to/eresearch-support) with your requirements and we can help you cost the requirements.


* * *
[Back to the top](#about-aqua-heading-target)
***

**For further help contact eResearch** \
Submit a ticket: [http://qut.to/eresearch-support](http://qut.to/eresearch-support) \
Email us: eresearch@qut.edu.au \
Call us: 07 3138 8899
