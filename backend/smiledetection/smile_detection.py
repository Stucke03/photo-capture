from fastapi import FastAPI, UploadFile, File
import numpy as np
import cv2, uvicorn

face_haar = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
smile_haar = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_smile.xml')

@app.post("/detect_smile")
async def detect_smile(file: UploadFile = File(...)):
    img_bytes = await file.read()
    np_arr = np.frombuffer(img_bytes, np.uint8)
    frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if frame is None:
        return {"error": "Could not decode the image."}

    grayscale = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    faces = face_haar.detectMultiScale(grayscale, scaleFactor=1.3, minNeighbors=5)
    
    smile_detected = False
    for (x, y, w, h) in faces:
        cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 2)
        smile_region = grayscale[y:y + h, x:x + w]
        smile = smile_haar.detectMultiScale(smile_region, scaleFactor=1.9, minNeighbors=30, minSize=(80, 80))
        if len(smile) > 0:
            smile_detected = True
            break
        #for (sx, sy, sw, sh) in smile:
            #cv2.rectangle(frame, (x + sx, y + sy), (x + sx + sw, y + sy + sh), (0, 255, 0), 2)
        #cv2.imshow('Smile Detection', frame)
    return {"smile_detected": smile_detected}

if __name__=="__main__": uvicorn.run(app,host="0.0.0.0",port=8000)
