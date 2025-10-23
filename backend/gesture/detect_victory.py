from fastapi import FastAPI, UploadFile, File
import numpy as np, cv2, mediapipe as mp, uvicorn

app=FastAPI()
h=mp.solutions.hands.Hands(static_image_mode=True,max_num_hands=2)

def v(l):
    return l[8].y<l[6].y and l[12].y<l[10].y and not(l[16].y<l[14].y)\
        and not(l[20].y<l[18].y)

@app.post("/detect")
async def d(f:UploadFile=File(...)):
    b=await f.read()
    a=np.frombuffer(b,np.uint8)
    img=cv2.imdecode(a,cv2.IMREAD_COLOR)
    r=h.process(cv2.cvtColor(img,cv2.COLOR_BGR2RGB))
    t=False
    if r.multi_hand_landmarks:
        for m in r.multi_hand_landmarks:
            if v(m.landmark): t=True; break
    return {"v":t}

if __name__=="__main__": uvicorn.run(app,host="0.0.0.0",port=8000)
