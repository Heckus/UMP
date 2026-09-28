---
title: Getting started with High-Performance Computing on Aqua
date: 2026-09-08
---
(getting-started-heading-target)=

****A High-Performance Compute (HPC) account gives you access to QUT's high-performance computing facilities, including the high-performance computing infrastructure, software, and file store.****

:::{admonition} Prerequisites
:class: tip
You will need to be a QUT staff member, research student, or visitor
:::

(apply-for-an-hpc-account)=
## Apply for an HPC account

1.  Complete the [HPC Account Request form](https://heat2.qut.edu.au/HEAT/Login.aspx?ProviderName=QUT+SAML&Role=SelfService&Scope=SelfServiceMobile&CommandId=NewServiceRequestByOfferingId&Tab=ServiceCatalog&Template=F86AFEC39A8C454A890E989D24914A8E).

Students will need to get their supervisor to authorise the request form. The turnaround for a new account is normally 48 hours.

2.  You will need to have at least one Data Management Plan to submit jobs on the HPC, as from 2nd Nov 2026 all jobs require an {abbr}`RPID (Research Project ID)`. If you don't yet have a plan, go to the [({abbr}`DMP (Data Management Planner)`)](https://data-mgmt-plan.qut.edu.au/) and create one.
  
***
(accessing-the-hpc)=
## Accessing the HPC

Communication to the HPC is provided using Secure Shell (SSH). SSH is a secure protocol and provides HPC users with login, command-line and secure file transfer access.

Access to the HPC is provided by the ‘login node' named Aqua. Users will connect to Aqua to prepare and submit jobs to the worker nodes for processing.

:::{important}
Aqua is a powerful computer however, it is not the HPC itself. Running tasks on Aqua, for example, by running commands directly on the command-line, is strongly discouraged as Aqua is only for submitting jobs. Tasks run directly on Aqua may be terminated without notice to prevent negatively impacting other users submitting their jobs.
:::


[Back to the top](#getting-started-heading-target)
* * *
(how-you-log-into-aqua-depends-on-the-operating-system-of-your-computer)=
## How you log into Aqua depends on the operating system of your computer.

:::{dropdown} Windows using PuTTY
****With PuTTY on Windows****

To login to Aqua via Windows you will need:

*   An SSH client program
    
*   A QUT Network connection
    

The QUT network connection means initiating the SSH connection from campus or, if remote you must first set up a [VPN connection to QUT.](https://qutvirtual4.qut.edu.au/group/student/it-and-printing/wi-fi-and-internet-access/accessing-resources-off-campus)

Although several SSH clients will work we recommend Putty. You can find PuTTY in ITassist on a QUT computer, the inbuilt system for installing software. If using a personal computer, the application can be installed from the [Putty website](http://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html).

To install Putty to a QUT computer in ITassist:

*   Search ‘ITassist' from your windows menu to launch the program. 
    
*   Choose ‘Install Software', and search for Putty in the available applications.
    
*   Choose an appropriate version for your computer.
    
*   ​Once it is downloaded, double-click the file and run the installer.
    
*   Locate then launch the Putty program. In Windows 10 it is listed in the Windows Menu at the top (you may need to click 'Expand' to see Putty).
    
*   In the Host Name box type (replacing `<username>` with your username):
    
```{code} bash
:linenos:
:emphasize-lines: 1
<username>@aqua.qut.edu.au
```
    
*   Click on Open and you should establish a connection to Aqua.
    
    You may be presented with a warning regarding the server's key not being cached in the registry.  This is expected when first connecting to Aqua.
    
    Select Yes to add the security key and connect.
    
*   At the login prompt type your password.
    
    You should now be logged in to Aqua.

:::

:::{dropdown} Windows using CMD prompt
****With CMD prompt on Windows****

To log in to Aqua first you must ensure that you have an active link to the QUT network. If you are connecting from outside of QUT, you must first establish a [VPN connection to QUT](https://qutvirtual4.qut.edu.au/group/student/it-and-printing/wi-fi-and-internet-access/accessing-resources-off-campus)

1.  Login to Aqua using Commandline. Commandline can be found by clicking the "Start" icon and typing "cmd".
    
2.  Enter the following command, where `<username>` is substituted by your own QUT username, such as n12234567 or a staff user id:
    

```{code} bash
:linenos:
:emphasize-lines: 1
ssh <username>@aqua.qut.edu.au
```

If this is your first time connecting via your computer, you will be asked if you want the identity of Aqua to be added to your known list of hosts.  This is a security measure and you should answer 'yes'.

3.  Enter your password when prompted, which is the same as your regular QUT password.

:::
:::{dropdown} Mac or Linux
****Command Line via Mac or Linux****

Both macOS and Linux are forms of UNIX and use the same basic technique for logging into Aqua. First, you must ensure that you have an active link to the QUT network. If you are connecting from outside of QUT, you must first establish a [VPN connection to QUT.](https://qutvirtual4.qut.edu.au/group/student/it-and-printing/wi-fi-and-internet-access/accessing-resources-off-campus)

1.  Login to Aqua using Terminal
    

If using macOS you can connect to Aqua using the Terminal program, located in Applications -> Utilities.

If using Linux the program is also called Terminal.

In either case, double-clicking on the program icon brings up a terminal window.

1.  Enter your username
    

If your QUT username is the same as your Mac or Linux username, type :

```{code} bash
:linenos:
:emphasize-lines: 1
ssh aqua.qut.edu.au 
```

Alternately, if your laptop or desktop username differs from your QUT username, you will need to specify this when invoking ssh, where `<username>` is substituted by your own QUT username, such as n12234567 or a staff user id:

```{code} bash
:linenos:
:emphasize-lines: 1
ssh <username>@aqua.qut.edu.au
```



If this is your first time connecting via your computer, you will be asked if you want the identity of Aqua to be added to your known list of hosts.  This is a security measure and you should answer 'yes'.

1.  Enter your password when prompted, which is the same as your regular QUT password.

You are now on the HPC, and can submit jobs, check on the status of your jobs, transfer data to the HPC etc.
:::
[![Screenshot of 'Logging in to Aqua on a Mac' video hosted on QUT's Mediahub](attachments/HPC-Training-Mac-Login_image.png)](https://mediahub.qut.edu.au/media/t/0_8zhxfh19)

***
(how-to-use-password-less-login)=
# How to use password-less login

We recommend that you use passwordless login. You can use passwordless login to avoid typing your username and password every time you connect to the HPC. The usual user/password challenge and authentication is replaced with a silent exchange of cryptographic keys.

:::{note}
This is beneficial as the same cryptographic keys will continue to work when QUT password changes.
:::

:::{dropdown} Windows instructions for passwordless login with PuTTY
PuTTY includes an application called PuTTYgen to create key pairs. Do the following on the computer that you'll use to connect to Aqua: 

**1. Generate the key pair**
* Run the PuTTYgen tool, which you will find in the start menu
```{image} attachments/PuTTYgen_menu.png
:alt: View of where to find the PuTTYgen software
:width: 600px
:align: center
```
* Select "Generate" in the PuTTYgen window. Move the mouse around to create the random values used in generating the key.
* Use the default RSA type of key in the Parameters section
```{image} attachments/PuTTYgen_generate.png
:alt: View of the PuTTYgen window where you generate the key
:width: 600px
:align: center
```
* Select all of the "Public key for pasting into OpenSSH authorized_keys file" from the Key window. This is the public key. Copy it to the clipboard to paste into a file later.
```{image} attachments/PuTTYgen_copy_key.png
:alt: View of the PuTTYgen window where you copy the public key
:width: 600px
:align: center
```
* Select "Save Private Key". Select "Yes" or "Accept" in the PuTTYgen Warning window regarding passphrases.
```{image} attachments/PuTTYgen_save_private_key.png
:alt: View of the PuTTYgen window with a warning window, select Yes
:width: 600px
:align: center
```
* Close the PuTTYgen application.

**2. Copy the public key to the remote device**

You will need to be on Aqua to do the following:
* Connect to Aqua via a standard password-protected SSH/PuTTY session and log in
* Use the command `mkdir ~.ssh` to create a directory named ~/.ssh (if you don't already have one)
* Enter the command `chmod 700 ~/.ssh`. This gives the users (owners) read, write and execute permissions.
* Use the command `nano ~/.ssh/authorized_keys` to create an empty text file named authorized_keys (if you don't already have one). If you already have a file `~/.ssh/authorized_keys` then use nano to edit it.
* Paste the contents of the "Public key for pasting into OpenSSH authorized_keys file" into the text file from your clipboard. Confirm you have pasted the key, and then save and close the file.
* Enter the command `chmod 600 ~/.ssh/authorized_keys`. This setting provides the user with read and write permissions on the authorized_keys file.
* Type `exit` to close the SSH connection.

**3. Configure the PuTTY client**

Use the main PuTTY application to configure the PuTTY client to use key-based authentication.
* Launch PuTTY but do not connect to the remote system.
* In the "Category window", browse to "Connection -> Data"
```{image} attachments/PuTTY_auto_login_username.png
:alt: View of the PuTTY window showing Category->Connection->Data 
:width: 600px
:align: center
```
* Set the "Auto-login username" to your Aqua `<username>`.
* Browse to "Connection -> SSH -> Auth -> Credentials". Select the "Browse" button next to the "Private key file for authentication". Find the location of the saved private key created with the PuTTYgen application.
```{image} attachments/PuTTY_private_key_browse.png
:alt: View of the PuTTY window showing Category->SSH->Auth->Credentials 
:width: 600px
:align: center
```
**4. Test the key-based authentication**

You are now ready to test the connection to Aqua. Expect the connection to be established without a password challenge.
* At the top of the "Category" window, select "session" to return to the main connection window. In the "Host Name (or IP address)" box, enter `<username>@aqua.qut.edu.au` (replacing the `<username>` with your Aqua username).
* Select "Open" to test the session. A message indicating "Authenticating with public key" will appear in the SSH connection window if key-based authenication was configured correctly.
```{image} attachments/PuTTY_session.png
:alt: View of the PuTTY window showing session
:width: 600px
:align: center
```
You've successfully configured PuTTY to use key-based authentication.
:::

:::{dropdown} Windows instructions for passwordless login on CMD prompt
Windows users can access ssh via the Command Line provided they are running Windows 10 or later.
* To access the command line click the Start icon and type cmd. From the results choose the Command Prompt App which should appear as: 
```{image} attachments/PLW1.png
:alt: View of Command Prompt showing default login screen
:width: 600px
:align: center
```
* At the prompt type: `ssh-keygen`
```{image} attachments/PLW2.png
:alt: View of Command Prompt asking for location to save your key
:width: 600px
:align: center
```
  * When asked the location to save your key accept the default location
  * When asked for a passphrase you can optionally add one. This adds an extra layer of security. This will require you to enter your passphrase to unlock the key. You can leave this field blank to skip this step.
  * Confirm your passphrase or enter to skip. You should then see:
```{image} attachments/PLW3_windows.png
:alt: View of Command Prompt showing key fingerprint
:width: 600px
:align: center
```
* At this prompt type the following replacing `<username>` with your QUT username:
```{code} bash
:linenos:
:emphasize-lines: 1
type .ssh\id_rsa.pub | ssh <username>@aqua.qut.edu.au "test -d ~/.ssh || mkdir ~/.ssh; cat >> ~/.ssh/authorized_keys"
```
This will copy your public key to Aqua and authorise you to connect using your private key.

* When prompted type your QUT password and you should see:
```{image} attachments/PLW4.png
:alt: View of Command Prompt showing key fingerprint
:width: 600px
:align: center
```
* Now type `Exit` to exit from Command Line and open Command line again. This time type:
`ssh <username>@aqua.qut.edu.au`

You won't need to enter a password. It will verify your identity from the public key you just copied.

:::

:::{dropdown} Mac instructions for passwordless login
Mac users can access ssh via the Terminal function.
* Open a terminal window
* At the prompt type: `ssh-keygen`
  * When asked the location to save your key accept the default location
  * When asked for a passphrase you can optionally add one. This adds an extra layer of security. This will require you to enter your passphrase to unlock the key. You can leave this field blank to skip this step.
  * Confirm your passphrase or enter to skip. You should then see this:
```{image} attachments/keypair.png
:alt: View of Terminal showing key's randomart image
:width: 900px
:align: center
```
* At this prompt type:
 `ssh-copy-id <username>@aqua.qut.edu.au`
  * When prompted type your QUT password and you should see something like this:
```{image} attachments/ssh-copy-id_image3.png
:alt: View of Terminal showing the HPC login screen
:width: 900px
:align: center
```
* Now type `exit` to exit from Terminal and open Terminal again. This time type:
  * `ssh <username>@aqua.qut.edu.au`
  
You won't need to enter a password. It will verify your identity from the public key you just copied.
```{image} attachments/Aqua_asci_art2.png
:alt: View of Terminal showing the HPC login screen
:width: 900px
:align: center
```
:::

***
[Back to the top](#getting-started-heading-target)
+++
***
:::{admonition} Resources used to write this page
:class: hint
*   [https://www.techtarget.com/searchsecurity/tutorial/How-to-use-PuTTY-for-SSH-key-based-authentication](https://www.techtarget.com/searchsecurity/tutorial/How-to-use-PuTTY-for-SSH-key-based-authentication)
:::
***

**For further help contact eResearch** \
Submit a ticket: [http://qut.to/eresearch-support](http://qut.to/eresearch-support) \
Email us: eresearch@qut.edu.au \
Call us: 07 3138 8899