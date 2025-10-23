Back-end for victory gesture detection.

How to use:
```conda env create -f environment.yml```

```conda activate photo-capture```

In one terminal window, run `python detect_victory.py`. This is the backend that will be running when the app opens.

If you want to test using your webcam, open another terminal window (with the env activated) and run `python webcam_testing.py`. This will open your webcam and 
print the boolean outputs for each frame.
