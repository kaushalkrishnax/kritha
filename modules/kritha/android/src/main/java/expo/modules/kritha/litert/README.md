# Kritha LiteRT Runtime

A small Android/Kotlin runtime layer over Google AI Edge LiteRT + LiteRT-LM.

## Scope

- Generic `.tflite` loading/execution through LiteRT `CompiledModel`.
- Model inspection: signatures, tensor types/shapes, buffer requirements.
- CPU/GPU/NPU/Qualcomm execution options exposed as one request model.
- Generic tensor execution for model-specific adapters.
- LLM execution delegated to LiteRT-LM. This runtime does not reimplement LiteRT-LM.
- OpenAPI tool definitions are passed through LiteRT-LM's `OpenApiTool`.
- Speech adapter registry for model-family pipelines. The adapters are intentionally thin: preprocessing/tokenization/decoding remain model-family concerns, while inference is centralized here.

This is an Android runtime layer, not a replacement implementation of LiteRT.
