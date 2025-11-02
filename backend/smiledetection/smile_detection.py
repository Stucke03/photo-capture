from fastapi import FastAPI, UploadFile, File
import numpy as np
import cv2, uvicorn
import mediapipe as mp

BaseOptions = mp.tasks.BaseOptions
FaceLandmarker = mp.tasks.vision.FaceLandmarker
landmarkerOptions = mp.tasks.vision.FaceLandmarkerOptions
runningMode = mp.tasks.vision.RunningMode

model_path = "face_landmarker.task"
options = landmarkerOptions(base_options=BaseOptions(model_asset_path=model_path),
    running_mode=runningMode.LIVE_STREAM,
    output_face_blendshapes=True)
landmarker = FaceLandmarker.create_from_options(options)

app = FastAPI()

@app.post("/detect_smile")
async def detect_smile(file: UploadFile = File(...)):
    img_bytes = await file.read()
    np_arr = np.frombuffer(img_bytes, np.uint8)
    frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if frame is None:
        return {"error": "Could not decode the image."}
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame)
    result = landmarker.detect(mp_image)
    
    smile_score = 0.0
    if result.output_face_blendshapes:
        for b in result.face_blendshapes[0]:
            if "mouthSmile" in b.category_name:
                smile_score += b.value
        smile_score /= 2.0 
    return {"smile_detected": smile_score > 0.5}

if __name__=="__main__": uvicorn.run(app,host="0.0.0.0",port=8000)
