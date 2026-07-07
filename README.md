# 🎙️ Whisper-Backend — Local Speech-to-Text Microservice

Whisper-Backend is a Python **FastAPI** microservice designed to provide fast, local speech-to-text transcription for the **Playlist Summarizer** project. It leverages `yt-dlp` for media stream extraction and `faster-whisper` (a highly optimized CTranslate2 reimplementation of OpenAI's Whisper model) to transcribe audio into text without relying on external cloud APIs.

---

## ✨ What It Does

When the Playlist Summarizer frontend needs a transcript for a video that lacks closed captions, it sends a POST request to Whisper-Backend with the video URL.

The service performs an automated 3-step pipeline:
1. **📥 Media Downloading (`yt_dlp`)**: Connects to YouTube and downloads the highest quality audio stream.
2. **🎵 Audio Extraction & Conversion**: Uses a background `FFmpegExtractAudio` postprocessor to convert the downloaded stream into a clean `192kbps MP3` audio file stored in a temporary UUID-tagged directory (`/tmp/<uuid>.mp3`).
3. **🧠 Neural Transcription (`faster-whisper`)**: Feeds the MP3 file into an in-memory Whisper neural network (defaulting to the `"base"` model with `int8` quantization on CPU for rapid processing) using a beam size of 5. It concatenates all speech segments into a clean transcript string, removes the temporary audio file to free up disk space, and returns the transcript.

---

## 🛠️ Prerequisites & System Dependencies

To run Whisper-Backend locally, you **MUST** have the following system dependency installed:

### 1. System Dependency: FFmpeg (MANDATORY)
`yt-dlp` requires the system binary `ffmpeg` to extract and convert audio streams. If `ffmpeg` is missing, transcription requests will fail.
- **Ubuntu / Debian / Linux**:
  ```bash
  sudo apt update && sudo apt install -y ffmpeg
  ```
- **macOS (Homebrew)**:
  ```bash
  brew install ffmpeg
  ```
- **Windows (Chocolatey / Scoop)**:
  ```bash
  choco install ffmpeg
  # or
  scoop install ffmpeg
  ```

---

## 🚀 How to Activate on Localhost

### Option A: ⚡ Automated One-Click Launch (`run_all.sh`)
An automated script, **`run_all.sh`**, is included directly inside this directory (and across every project folder). You can launch the entire setup effortlessly by running:
```bash
./run_all.sh
```
**By running this single script, it does the rest of the job automatically:**
1. **Creates Python Virtual Environments**: Automatically initializes `venv_whisper` (and `venv_humanify_ml`) if missing.
2. **Installs Modules & Dependencies**: Automatically runs `pip install -r requirements.txt` and `npm install` for all workspace apps.
3. **Sets Up Databases & Configs**: Automatically initializes the SQLite database via Prisma and creates `.env` files from templates.
4. **Starts All Services**: Launches both Next.js frontends (`3000`, `3001`) and FastAPI backends (`8000`, `8001`) in background threads.

> [!IMPORTANT]
> **What You Need to Provide**:
> - **System Tool**: Ensure `ffmpeg` is installed on your OS (`sudo apt install ffmpeg` or `brew install ffmpeg`).
> - **API Keys**: Ensure you enter your `YOUTUBE_API_KEY` in `playlist-summarizer/.env` and provide an **OpenRouter API key** directly on the web UI when summarizing videos.
> - **Fine-Tuned Models**: For custom neural synonym generation in `ml-engine`, download the models from the [Google Drive Link](https://drive.google.com/drive/folders/1g3x9jr7xrMNGzDqDqxp5wR8UL1Fdsu1k?usp=drive_link) and place them inside `ml-engine/models/`.

---

### Option B: Running Standalone (Manual Setup)
To run only Whisper-Backend manually on port `8001`:
```bash
cd path/to/Projects/whisper-backend

# Create & activate virtual environment
python3 -m venv venv_whisper
source venv_whisper/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start server
python main.py
```
Or directly with uvicorn:
```bash
uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```
Once started, you can access:
- **API Health / Base**: `http://localhost:8001`
- **Interactive Swagger Documentation**: `http://localhost:8001/docs`

---

## 🔑 Environment Variables & Keys

Whisper-Backend is **100% self-contained and offline-capable**. It requires **NO external API keys** or cloud subscriptions. The Whisper model weights are automatically downloaded and cached locally on first run.

---

## 🔌 API Endpoint Reference

### `POST /api/transcribe`
Downloads audio from a video URL and returns its full text transcript.

#### Request Body (JSON):
```json
{
  "video_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
}
```

#### Response Body (JSON):
```json
{
  "transcript": "We're no strangers to love. You know the rules and so do I..."
}
```

---

## ⚙️ Model Customization & Performance Tuning

In `main.py`, the model is initialized globally:
```python
model = WhisperModel("base", device="cpu", compute_type="int8")
```
- **Speed vs. Accuracy**: You can change `"base"` to `"tiny"`, `"small"`, `"medium"`, or `"large-v3"`. Larger models provide higher accuracy for complex audio or accents but require significantly more RAM and CPU/GPU processing time.
- **GPU Acceleration**: If you have an NVIDIA GPU with CUDA installed, you can change `device="cpu"` to `device="cuda"` and `compute_type="float16"` for a 10x-30x speed boost.

---

## 💡 Code Improvements Made for Easier Running
- **Automated Script Inclusion**: Added a self-configuring `run_all.sh` launcher directly inside this folder for instant execution.
- **CORS Support Enabled**: Added FastAPI `CORSMiddleware` with `allow_origins=["*"]` to `main.py`. This prevents Cross-Origin Resource Sharing errors when the frontend or testing tools interact directly with the transcription endpoint.
