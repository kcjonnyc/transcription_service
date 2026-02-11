import axios from 'axios';
import { TranscriptionResponse, Mode } from '../types';

export async function transcribeAudio(
  file: File,
  mode: Mode,
  translate: boolean = false
): Promise<TranscriptionResponse> {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('mode', mode);
  if (translate) {
    formData.append('translate', 'true');
  }

  const response = await axios.post<TranscriptionResponse>('/api/transcribe', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });

  return response.data;
}
