Change-TwitterProfile

This PowerShell script currently updates your Twitter name, description, avatar, and banner to randomly chosen preset values every 33 seconds.

This script uses some functions from the awesome PSTwitterAPI PowerShell Module: https://github.com/mkellerman/PSTwitterAPI.
It is unlikely that you will need to download the whole module to run this script, as I have included the functions in my script. 

Figuring out how to upload the images in chunks was a pain in the ass! I need to credit MyTwitter: https://github.com/MyTwitter/MyTwitter as their way of solving this issue was an inspiration for me, and essentially helped me complete the goals of my script.

![image](https://user-images.githubusercontent.com/42836083/156212947-bee7022e-9f2e-42cf-9579-4207e0e7ce39.png)

1) Download Zip from github https://github.com/OneOfThePetes/Change-TwitterProfile/archive/refs/heads/main.zip 
2) Extract file on your machine
3) Get your Twitter Developer account - You need the API Key and API Secret (for help: https://developer.twitter.com/en/docs/twitter-api/getting-started/getting-access-to-the-twitter-api)
4) You need to create a twitter app (https://developer.twitter.com/en/portal/projects-and-apps) - From that you need the Access Token, and Access Token Secret
5) Get those things, and put each in the correct file in the /creds directory
6) Edit text files in /text directory
7) Put avatar images in the /images folder
8) Put banner images in the /banner folder
9) Run the script with PowerShell 
10) Check twitter profile 

PowerShell 5.1 Required as a minimum.
PowerShell bundled with Windows 10 will work.
PowerShell 6 and up also work! (Untested on Linux and Mac)
Older versions of windows will require a Windows PowerShell update (or PowerShell core download)
My script handles running PowerShell with the correct TLS type for really old Windows versions (like Server 2012 R2, where I run my script)
