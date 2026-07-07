#!/bin/bash
set -e

# Detect current directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine root Projects directory
if [ -d "$SCRIPT_DIR/humanify" ] && [ -d "$SCRIPT_DIR/ml-engine" ]; then
    PROJECTS_DIR="$SCRIPT_DIR"
elif [ -d "$SCRIPT_DIR/../humanify" ] && [ -d "$SCRIPT_DIR/../ml-engine" ]; then
    PROJECTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    PROJECTS_DIR="$SCRIPT_DIR"
fi

echo "===================================================================="
echo "🚀 AI Projects Workspace — Automated Setup & Service Launcher"
echo "===================================================================="
echo "Workspace Root detected at: $PROJECTS_DIR"
echo ""

# Check system dependencies
echo "🔍 Checking system dependencies..."
for cmd in python3 node npm; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Error: Required system tool '$cmd' is not installed. Please install it first."
        exit 1
    fi
done

if ! command -v ffmpeg &> /dev/null; then
    echo "⚠️  Warning: 'ffmpeg' is not installed! Whisper-Backend requires ffmpeg for audio transcription."
    echo "   Please install ffmpeg (e.g., 'sudo apt install ffmpeg' or 'brew install ffmpeg')."
fi
echo "✅ System tools verified."
echo ""

# 1. Clean up ports 3000, 3001, 8000, 8001
echo "🧹 Cleaning up existing processes on ports 3000, 3001, 8000, 8001..."
for port in 3000 3001 8000 8001; do
    if fuser ${port}/tcp >/dev/null 2>&1; then
        echo "   Killing process on port $port..."
        fuser -k ${port}/tcp >/dev/null 2>&1 || true
    fi
done
echo "✅ Ports cleaned."
echo ""

# 2. Setup & Start ml-engine (Port 8000)
echo "[1/4] 🤖 Setting up and starting ml-engine on Port 8000..."
cd "$PROJECTS_DIR/ml-engine"
if [ ! -d "venv_humanify_ml" ]; then
    echo "   Creating Python virtual environment 'venv_humanify_ml'..."
    python3 -m venv venv_humanify_ml
fi
source venv_humanify_ml/bin/activate
echo "   Installing/verifying Python dependencies..."
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt

# Check for fine-tuned models
if [ ! -d "models/humanify-roberta-agnews" ]; then
    echo "   ℹ️  Fine-tuned models not found in ./models/. Server will fallback to roberta-base online weights."
    echo "       (Download custom models from: https://drive.google.com/drive/folders/1g3x9jr7xrMNGzDqDqxp5wR8UL1Fdsu1k?usp=drive_link)"
fi

python app.py > /tmp/ml-engine.log 2>&1 &
ML_ENGINE_PID=$!
deactivate
echo "   ✅ ml-engine running in background (PID: $ML_ENGINE_PID)"
echo ""

# 3. Setup & Start whisper-backend (Port 8001)
echo "[2/4] 🎙️ Setting up and starting whisper-backend on Port 8001..."
cd "$PROJECTS_DIR/whisper-backend"
if [ ! -d "venv_whisper" ]; then
    echo "   Creating Python virtual environment 'venv_whisper'..."
    python3 -m venv venv_whisper
fi
source venv_whisper/bin/activate
echo "   Installing/verifying Python dependencies..."
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt

python main.py > /tmp/whisper-backend.log 2>&1 &
WHISPER_PID=$!
deactivate
echo "   ✅ whisper-backend running in background (PID: $WHISPER_PID)"
echo ""

# 4. Setup & Start humanify (Port 3000)
echo "[3/4] 🧠 Setting up and starting humanify frontend on Port 3000..."
cd "$PROJECTS_DIR/humanify"
if [ ! -f ".env.local" ] && [ -f ".env.example" ]; then
    echo "   Creating .env.local from .env.example..."
    cp .env.example .env.local
fi
if [ ! -d "node_modules" ]; then
    echo "   Installing Node modules (npm install)..."
    npm install --silent
fi

npm run dev > /tmp/humanify.log 2>&1 &
HUMANIFY_PID=$!
echo "   ✅ humanify dev server running in background (PID: $HUMANIFY_PID)"
echo ""

# 5. Setup & Start playlist-summarizer (Port 3001)
echo "[4/4] 📑 Setting up and starting playlist-summarizer frontend on Port 3001..."
cd "$PROJECTS_DIR/playlist-summarizer"
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    echo "   Creating .env from .env.example..."
    cp .env.example .env
fi
if [ ! -d "node_modules" ]; then
    echo "   Installing Node modules (npm install)..."
    npm install --silent
fi
echo "   Initializing/verifying SQLite database via Prisma..."
npx prisma db push --skip-generate > /dev/null 2>&1 || npx prisma db push > /dev/null 2>&1

npm run dev > /tmp/playlist-summarizer.log 2>&1 &
PLAYLIST_PID=$!
echo "   ✅ playlist-summarizer dev server running in background (PID: $PLAYLIST_PID)"
echo ""

echo "===================================================================="
echo "🎉 All services setup and launched successfully!"
echo "===================================================================="
echo "📍 Service URLs:"
echo "   • Humanify Dashboard:       http://localhost:3000"
echo "   • ML-Engine API Docs:       http://localhost:8000/docs"
echo "   • Playlist Summarizer UI:   http://localhost:3001"
echo "   • Whisper-Backend API Docs: http://localhost:8001/docs"
echo ""
echo "📝 To view live logs in another terminal, run:"
echo "   tail -f /tmp/ml-engine.log"
echo "   tail -f /tmp/whisper-backend.log"
echo "   tail -f /tmp/humanify.log"
echo "   tail -f /tmp/playlist-summarizer.log"
echo ""
echo "⚠️  NOTE: Ensure you configure your API keys (YOUTUBE_API_KEY in playlist-summarizer/.env"
echo "         and OpenRouter API key on the UI) and place downloaded models into ml-engine/models/."
echo "===================================================================="
echo "🛑 Press Ctrl+C to stop all background services."

# Function to handle termination
cleanup() {
    echo ""
    echo "🛑 Stopping all project services..."
    kill $ML_ENGINE_PID 2>/dev/null || true
    kill $WHISPER_PID 2>/dev/null || true
    kill $HUMANIFY_PID 2>/dev/null || true
    kill $PLAYLIST_PID 2>/dev/null || true
    
    for port in 3000 3001 8000 8001; do
        fuser -k ${port}/tcp >/dev/null 2>&1 || true
    done
    
    echo "✅ All project services cleanly stopped."
    exit 0
}

# Trap SIGINT (Ctrl+C)
trap cleanup SIGINT

# Wait for background processes to keep script running
wait $ML_ENGINE_PID $WHISPER_PID $HUMANIFY_PID $PLAYLIST_PID || true
