Change-TwitterProfile

This PowerShell script currently updates your Twitter name, description, location, avatar, and banner to randomly chosen preset values every 30 seconds.



https://user-images.githubusercontent.com/42836083/158079790-1e6e9062-d62b-4733-9f15-1be1e6ff3293.mp4



![image](https://user-images.githubusercontent.com/42836083/156651402-c59eb588-695c-41fe-9ff3-adbe29a6a874.png)
![image](https://user-images.githubusercontent.com/42836083/156651480-c5b31d47-5bec-426b-b259-fcfa6043dd4d.png)


1) Download Zip from github https://github.com/OneOfThePetes/Change-TwitterProfile/archive/refs/heads/main.zip 
2) Extract file on your machine
3) Get your Twitter Developer account - You need the API Key and API Secret (for help: https://developer.twitter.com/en/docs/twitter-api/getting-started/getting-access-to-the-twitter-api)
4) You need to create a twitter app with OAuth 1.0a turned on (https://developer.twitter.com/en/portal/projects-and-apps) - From that app you need the Access Token, and Access Token Secret. 
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

Credits:

This script uses some functions from the awesome PSTwitterAPI PowerShell Module: https://github.com/mkellerman/PSTwitterAPI.
It is unlikely that you will need to download the whole module to run this script, as I have included the functions in my script. 

Figuring out how to upload the images in chunks was a pain in the ass! I need to credit MyTwitter: https://github.com/MyTwitter/MyTwitter as their way of solving this issue was an inspiration for me, and essentially helped me complete the goals of my script.

I've used some code from the awesome OutConsolePicture too!: From https://github.com/NotNotWrongUsually/OutConsolePicture
