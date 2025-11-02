import cv2, requests, time

u='http://127.0.0.1:8000/detect_smile'
c=cv2.VideoCapture(0)
while True:
    r, f=c.read()
    if not r:
        print("failed")
        break
    _,b=cv2.imencode('.jpg',f)
    
    files = {'file':('f.jpg',b.tobytes(),'image/jpeg')}
    response = requests.post(u, files=files)
    print(response.json())

    cv2.imshow('Webcam', f)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break
c.release()
