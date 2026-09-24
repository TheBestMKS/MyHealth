# MyHealth patch

This directory vendors `lib_llama_cpp` 0.7.3 under its MIT license.

MyHealth adds `enable_thinking: false` to the llama.cpp chat-template request.
Qwen3.5 otherwise spends the small mobile token budget on an exposed
`<think>` block. The patch keeps local replies fast and returns only the
user-facing answer. Native platform packages remain the unmodified 0.7.3
prebuilt dependencies from pub.dev.

MyHealth also caps the logical batch at 512 tokens and the physical micro-batch
at 256 tokens. Prompts are still evaluated in full, while the smaller compute
buffer lowers peak RAM on mobile devices.
