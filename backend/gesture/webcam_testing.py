import cv2, requests, time

u='http://127.0.0.1:8000/detect'
c=cv2.VideoCapture(0)
while True:
    r, f=c.read()
    if not r: break
    _,b=cv2.imencode('.jpg',f)
    try:
        x=requests.post(u,files={'f':('f.jpg',b.tobytes(),'image/jpeg')})
        print(x.json()['v'])
    except: pass
    time.sleep(0.3)
c.release()
