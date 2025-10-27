import cv2, time

face_haar = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
smile_haar = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_smile.xml')

webcam = cv2.VideoCapture(0)
if not webcam.isOpened():
    print("Error: Webcam not opened.")
    exit()

photo_saved = False
while True:
    ret, frame = webcam.read()
    if not ret:
        break
    grayscale = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    face = face_haar.detectMultiScale(grayscale, scaleFactor=1.3, minNeighbors=5)
    for (x, y, w, h) in face:
        cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 2)
        smile_region = grayscale[y:y + h, x:x + w]
        smile = smile_haar.detectMultiScale(smile_region, scaleFactor=1.9, minNeighbors=30, minSize=(80, 80))

        if len(smile) > 0 and not photo_saved:
            timestamp = int(time.time())
            cv2.imwrite(f"smile_{timestamp}.png", frame)
            cv2.putText(frame, "Smiling", (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)
            print(f"Photo saved")
            photo_saved = True
            break

        for (sx, sy, sw, sh) in smile:
            cv2.rectangle(frame, (x + sx, y + sy), (x + sx + sw, y + sy + sh), (0, 255, 0), 2)

    cv2.imshow('Smile Detection', frame)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

webcam.release()
cv2.destroyAllWindows()