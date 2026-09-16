package expo.modules.kritha.litert.speech

/**
 * Example manifest shape. The runtime intentionally keeps this explicit because
 * a .tflite file cannot reliably tell the application how to preprocess audio,
 * tokenize text, decode autoregressive logits, or synthesize PCM.
 *
 * {
 *   "id": "whisper-tiny",
 *   "architecture": "whisper",
 *   "task": "speech-to-text",
 *   "modelPath": "/data/user/0/.../whisper.tflite",
 *   "signature": "encode",
 *   "inputNames": ["input"],
 *   "outputNames": ["output"],
 *   "outputTypes": ["FLOAT"],
 *   "audio": {"sampleRate": 16000, "channels": 1},
 *   "mel": {"fftSize": 400, "hopLength": 160, "nMels": 80},
 *   "startTokenId": 50258,
 *   "stopTokenId": 50257,
 *   "maxDecodeTokens": 128,
 *   "metadata": {
 *      "encoderSignature": "encode",
 *      "decoderSignature": "decode",
 *      "decoderInput": "input_ids",
 *      "vocabSize": "51865"
 *   }
 * }
 */
object SpeechManifests
