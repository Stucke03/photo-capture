# A Comparative Study of Hands-Free Photo Interaction Methods 

We are investigating the performance of hands-free photo interaction methods and how they compare to each other in terms of reliability, usability and workload. Currently, most camera applications only provide the option to use a timer setting for hands-free photo capture on mobile devices. However, this setting has been commonly dubbed as unreliable and unusable by many, often due to the challenge of being ready for the capture at the exact time when the countdown goes to 0. There are other hands-free photo interaction methods that have been researched and engineered, such as gesture detection and remote capture. However, there is a lack of comparative study of these methods on a single application. In this project, we aim to study four methods in tandem and quantitatively measure reliability, usability and workload perceived by users when using these methods. 

This is the codebase for the application we use for our experiments.


# Instructions

## How to download the app onto your phone
1. Make sure Xcode is downloaded on your computer or laptop
2. Make sure iPhone is in developer mode
3. Clone this repository into Xcode
4. Connect your iPhone to your computer or laptop
5. Set iPhone as target destination
6. Run the program (this will download the app onto your iPhone)

## How to use the app
1. Open the app on your phone (if not downloaded, follow the steps above)
2. In the text box, type the name of the desired album to store photos, and press 'Use'
3. Open the dashboard
4. Select desired photo capture method (smile-detection, gesture-detection, timer, remote trigger)

   ### Smile-detection
   This capture method will look for the user to smile. Once it detects a smile, it will initiate a 5-second timer. Once the timer has ended, the photo will be taken and stored in the previously designated photo album.

   ### Gesture-detection
   This capture method will look for the user to make a 'V' with their middle and index fingers. Once it detects a 'V', it will initiate a 5-second timer. Once the timer has ended, the photo will be taken and stored in the previously designated photo album.

   ### Timer
   This capture method will initiate a 10-second timer. Once the timer has ended, the photo will be taken and stored in the previously designated photo album.

   ### Remote Trigger
   This capture method will wait for the user to activate the remote trigger. Once activated, it will initiate a 5-second timer. Once the timer has ended, the photo will be taken and stored in the previously designated photo album.
