import 'package:kritha/models/chat_message.dart';

/// Test-only conversation fixture. Production starts with an empty history.
List<ChatMessage> demoMessages() {
  return [
    ChatMessage(
      id: 'seed-1',
      role: ChatRole.assistant,
      createdAt: DateTime(2026, 10, 21, 9, 41),
      text: r'''## Good morning, Kaushal

I'm **Kritha**, running fully on-device. This build is a size-measurement fixture for the proposed Flutter stack:

- Markdown, tables and task lists via `gpt_markdown`
- Fenced code with syntax highlighting
- Inline and block LaTeX
- Local history in SQLite through **Drift**

> No backend, no bundled AI models. LiteRT-LM stays out of the base APK.''',
    ),
    ChatMessage(
      id: 'seed-2',
      role: ChatRole.user,
      createdAt: DateTime(2026, 10, 21, 9, 42),
      text: 'Show me a compact Dart example and the softmax formula it uses.',
    ),
    ChatMessage(
      id: 'seed-3',
      role: ChatRole.assistant,
      createdAt: DateTime(2026, 10, 21, 9, 42),
      text: r'''### Softmax in Dart

```dart
import 'dart:math' as math;

List<double> softmax(List<double> logits) {
  final maxLogit = logits.reduce(math.max);
  final exps = logits.map((x) => math.exp(x - maxLogit)).toList();
  final total = exps.reduce((a, b) => a + b);
  return [for (final value in exps) value / total];
}

void main() {
  print(softmax([2.0, 1.0, 0.1])); // [0.66, 0.24, 0.10]
}
```

Subtracting the maximum logit is a numerical-stability trick: `exp(x)` overflows for large `x`, while the ratio itself is unchanged.

| Logit | Probability |
| ----: | ----------: |
| 2.0 | 0.659 |
| 1.0 | 0.242 |
| 0.1 | 0.099 |''',
    ),
    ChatMessage(
      id: 'seed-4',
      role: ChatRole.user,
      createdAt: DateTime(2026, 10, 21, 9, 43),
      text: 'And the attention equation behind it?',
    ),
    ChatMessage(
      id: 'seed-5',
      role: ChatRole.assistant,
      createdAt: DateTime(2026, 10, 21, 9, 43),
      text: r'''The scaled dot-product attention used by transformers is

$$
\mathrm{Attention}(Q, K, V) =
  \mathrm{softmax}\!\left(\frac{QK^\top}{\sqrt{d_k}}\right)V
$$

where \(d_k\) is the key dimension. For one query \(q\), each key gets the weight

$$
\alpha_i = \frac{\exp(q \cdot k_i / \sqrt{d_k})}
  {\sum_j \exp(q \cdot k_j / \sqrt{d_k})}
$$

- [x] Render Markdown
- [x] Highlight Dart
- [x] Typeset LaTeX

Tap **Runtime** in the header to inspect the packages doing the work.''',
    ),
  ];
}
