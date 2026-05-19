from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import yt_dlp
from faster_whisper import WhisperModel
import os
import uuid

app = FastAPI()

# Load model globally (loads into memory once). "base" or "small" is fast.
# Change to "medium" or "large-v3" for better accuracy but slower speed.
model = WhisperModel("base", device="cpu", compute_type="int8")

class TranscribeRequest(BaseModel):
    video_url: str

def download_audio(url: str, output_path: str):
    ydl_opts = {
        'format': 'bestaudio/best',
        'outtmpl': output_path,
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': '192',
        }],
        'quiet': True,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])

@app.post("/api/transcribe")
async def transcribe(req: TranscribeRequest):
    try:
        temp_id = str(uuid.uuid4())
        audio_file = f"/tmp/{temp_id}.mp3"
        
        # 1. Download Audio
        download_audio(req.video_url, f"/tmp/{temp_id}")
        
        # 2. Transcribe
        segments, info = model.transcribe(audio_file, beam_size=5)
        text = " ".join([segment.text for segment in segments])
        
        # 3. Cleanup
        if os.path.exists(audio_file):
            os.remove(audio_file)
            
        return {"transcript": text.strip()}
    except Exception as e:
        print(f"Error during transcription: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
