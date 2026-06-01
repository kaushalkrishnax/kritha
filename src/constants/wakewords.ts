export const WAKEWORD_MODEL = "hey_coach.onnx";

export const WAKEWORD_THRESHOLD = 0.9999;

export const WAKEWORD_BUFFER_COUNT = 3;

interface InstanceConfig {
  id: string;
  modelName: string;
  threshold: number;
  bufferCnt: number;
  sticky: boolean;
}

export const wakeWordConfigs: InstanceConfig[] = [
  {
    id: "hey coach",
    modelName: "hey_coach.onnx",
    threshold: 0.9999,
    bufferCnt: 3,
    sticky: false,
  },
  // {
  //   id: "ok kritha",
  //   modelName: "ok_kritha.onnx",
  //   threshold: 0.9999,
  //   bufferCnt: 3,
  //   sticky: false,
  // },
  // {
  //   id: "kritha",
  //   modelName: "kritha.onnx",
  //   threshold: 0.9999,
  //   bufferCnt: 3,
  //   sticky: false,
  // },
];