# Transcription Service

A web app for audio transcription, translation, and disfluency analysis, powered by OpenAI.

## Features

- **Two modes**: Transcribe & Translate and Disfluency Analysis
- Audio file upload (drag-and-drop) supporting MP3, MP4, WAV, WEBM, FLAC, OGG, M4A (max 25 MB)
- Optional English translation via LLM
- Disfluency analysis with both regex-based and LLM-based detection
- Color-coded transcript highlighting by disfluency category

## Tech Stack

- **Backend**: Ruby / Sinatra, Puma, OpenAI API (`ruby-openai` gem)
- **Frontend**: React 19, TypeScript, Vite

## Prerequisites

- Ruby (with Bundler)
- Node.js (with npm)
- An OpenAI API key

## Setup

### Backend

```sh
cd backend
bundle install
```

Create a `.env` file in the `backend/` directory:

```
OPENAI_API_KEY=your-key-here
# Optional:
# OPENAI_BASE_URL=https://api.openai.com
# LOG_LEVEL=debug
```

Start the server:

```sh
bundle exec rackup config.ru
# Runs on http://localhost:9292
```

### Frontend

```sh
cd frontend
npm install
npm run dev
# Runs on http://localhost:5173, proxies /api to the backend
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/health` | Health check |
| `POST` | `/api/transcribe` | Transcribe audio |

### POST /api/transcribe

Multipart form parameters:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | file | yes | Audio file to transcribe |
| `mode` | string | yes | `transcribe` or `disfluency` |
| `translate` | string | no | Set to `true` for English translation |
