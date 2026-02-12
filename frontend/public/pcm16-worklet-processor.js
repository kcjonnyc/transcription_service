/**
 * AudioWorklet processor that converts Float32 microphone samples
 * to PCM16 Int16Array and posts buffers to the main thread.
 *
 * Must be served as a plain JS file from /public (not bundled).
 */
class PCM16WorkletProcessor extends AudioWorkletProcessor {
  process(inputs) {
    const input = inputs[0];
    if (input && input.length > 0) {
      const float32Data = input[0];
      const int16Data = new Int16Array(float32Data.length);

      for (let i = 0; i < float32Data.length; i++) {
        const s = Math.max(-1, Math.min(1, float32Data[i]));
        int16Data[i] = s < 0 ? s * 0x8000 : s * 0x7fff;
      }

      this.port.postMessage(int16Data.buffer, [int16Data.buffer]);
    }
    return true;
  }
}

registerProcessor('pcm16-worklet-processor', PCM16WorkletProcessor);
