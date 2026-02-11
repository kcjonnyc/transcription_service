import { useState, useRef, DragEvent, ChangeEvent } from 'react';
import { Mode } from '../types';

interface AudioUploaderProps {
  onUpload: (file: File, translate: boolean) => void;
  mode: Mode;
  isLoading: boolean;
}

const ACCEPTED_FORMATS = '.mp3,.mp4,.wav,.webm,.flac,.ogg,.m4a';
const MAX_SIZE_MB = 25;

function AudioUploader({ onUpload, mode, isLoading }: AudioUploaderProps) {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [translate, setTranslate] = useState(false);
  const [isDragOver, setIsDragOver] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  function validateFile(file: File): boolean {
    const validExtensions = ['mp3', 'mp4', 'wav', 'webm', 'flac', 'ogg', 'm4a'];
    const extension = file.name.split('.').pop()?.toLowerCase() || '';
    if (!validExtensions.includes(extension)) {
      setError(`Invalid file type: .${extension}. Accepted formats: ${validExtensions.join(', ')}`);
      return false;
    }
    if (file.size > MAX_SIZE_MB * 1024 * 1024) {
      setError(`File is too large. Maximum size is ${MAX_SIZE_MB}MB.`);
      return false;
    }
    setError(null);
    return true;
  }

  function handleFileSelect(file: File) {
    if (validateFile(file)) {
      setSelectedFile(file);
    } else {
      setSelectedFile(null);
    }
  }

  function handleDragOver(e: DragEvent<HTMLDivElement>) {
    e.preventDefault();
    setIsDragOver(true);
  }

  function handleDragLeave(e: DragEvent<HTMLDivElement>) {
    e.preventDefault();
    setIsDragOver(false);
  }

  function handleDrop(e: DragEvent<HTMLDivElement>) {
    e.preventDefault();
    setIsDragOver(false);
    const files = e.dataTransfer.files;
    if (files.length > 0) {
      handleFileSelect(files[0]);
    }
  }

  function handleInputChange(e: ChangeEvent<HTMLInputElement>) {
    const files = e.target.files;
    if (files && files.length > 0) {
      handleFileSelect(files[0]);
    }
  }

  function handleSubmit() {
    if (selectedFile && !isLoading) {
      onUpload(selectedFile, translate);
    }
  }

  function formatFileSize(bytes: number): string {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  }

  return (
    <div className="audio-uploader">
      <div
        className={`drop-zone ${isDragOver ? 'drag-over' : ''} ${selectedFile ? 'has-file' : ''}`}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onClick={() => fileInputRef.current?.click()}
      >
        <input
          ref={fileInputRef}
          type="file"
          accept={ACCEPTED_FORMATS}
          onChange={handleInputChange}
          className="file-input-hidden"
        />
        {selectedFile ? (
          <div className="selected-file-info">
            <div className="file-icon">&#127925;</div>
            <div className="file-details">
              <span className="file-name">{selectedFile.name}</span>
              <span className="file-size">{formatFileSize(selectedFile.size)}</span>
            </div>
            <button
              className="change-file-btn"
              onClick={(e) => {
                e.stopPropagation();
                setSelectedFile(null);
                setError(null);
                if (fileInputRef.current) {
                  fileInputRef.current.value = '';
                }
              }}
            >
              Change
            </button>
          </div>
        ) : (
          <div className="drop-zone-content">
            <div className="drop-zone-icon">&#128228;</div>
            <p className="drop-zone-text">
              Drag and drop an audio file here, or click to browse
            </p>
            <button className="choose-file-btn" onClick={(e) => { e.stopPropagation(); fileInputRef.current?.click(); }}>
              Choose File
            </button>
          </div>
        )}
      </div>

      {error && <div className="upload-error">{error}</div>}

      <div className="upload-info">
        Accepted formats: MP3, MP4, WAV, WEBM, FLAC, OGG, M4A (max {MAX_SIZE_MB}MB)
      </div>

      <div className="upload-options">
        {mode === 'merchant_buyer' && (
          <label className="translate-checkbox">
            <input
              type="checkbox"
              checked={translate}
              onChange={(e) => setTranslate(e.target.checked)}
            />
            <span className="checkbox-label">Translate to English</span>
          </label>
        )}
      </div>

      <button
        className="transcribe-btn"
        onClick={handleSubmit}
        disabled={!selectedFile || isLoading}
      >
        {isLoading ? 'Transcribing...' : 'Transcribe'}
      </button>
    </div>
  );
}

export default AudioUploader;
