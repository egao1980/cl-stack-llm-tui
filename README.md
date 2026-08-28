# cl-stack-llm-tui

TUI desk agent: **LM Studio** (OpenAI-compat) or in-process **vllm.cpp**, plus a small tool set and a **stdio MCP server** that shares the same file tools.

Not the [cl-stack-llm-demo](https://github.com/egao1980/cl-stack-llm-demo) canary — that one is non-interactive generate/sampling smoke. This is a chat loop.

```
you ──► agent "desk"
          ├─ now / calc          (in-process)
          └─ list_dir / read_file / write_note / search_files
               same handlers ──► stdio MCP (scripts/mcp-server.lisp)

backend:  LM Studio :1234/v1   or   vllm.cpp GGUF (optional system)
```

`cl-stack-llm-tui` does **not** depend on `vllm-cpp`. Live GGUF path is `cl-stack-llm-tui/vllm`.

Clone this repo only. Deps from [`ghcr.io/egao1980/cl-systems`](https://github.com/egao1980/cl-stack-systems) via [`cl-repository-client`](https://github.com/egao1980/cl-repository). No sibling checkouts.

## Prereqs

| Tool | Notes |
|------|--------|
| [Roswell](https://roswell.github.io/) + SBCL | `ros install sbcl-bin` |
| [oras](https://oras.land/) | client + package pull |
| [LM Studio](https://lmstudio.ai/) | optional; local OpenAI server on `:1234` |

If `ros -l scripts/install.lisp` dies with `X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY`, point `SSL_CERT_FILE` at your OpenSSL CA bundle (Homebrew: `/opt/homebrew/etc/openssl@3/cert.pem`).

## Install

```bash
git clone https://github.com/egao1980/cl-stack-llm-tui
cd cl-stack-llm-tui
./scripts/setup-client.sh      # cl-repository-client → ./.cl-repository
ros -l scripts/install.lisp    # .asd deps from GHCR (no CUDA overlay)
```

## Mock (no server, no GPU)

```bash
ros -l scripts/run-mock.lisp
ros -l scripts/run-tests.lisp
```

## Chat

TTY → alt-screen TUI. Pipe / `LLM_TUI_LINE=1` → line mode.

```bash
# copy workspace .env here, or: cp .env.example .env
# Auth on: LM Studio → Developer → Manage Tokens (sk-lm-…). Dummy `lm-studio` is a condition.
LLM_TUI_BACKEND=lmstudio ros -l scripts/tui.lisp

# scripted backend
LLM_TUI_BACKEND=mock LLM_TUI_LINE=1 ros -l scripts/tui.lisp
```

Searches `.env` in `LLM_TUI_ENV`, cwd, `LLM_TUI_ROOT`, this checkout, then the parent workspace. 401 / dummy token → `lmstudio-auth-error` with `USE-VALUE`, `CONTINUE` (no Authorization), `LOAD-ENV`, `RETRY`.

Slash commands: `/help` `/clear` `/backend mock|lmstudio|vllm` `/quit`.

## vllm.cpp (optional)

```bash
ros -l scripts/install-vllm.lisp
VLLM_MODEL_PATH=/path/to/model.gguf LLM_TUI_BACKEND=vllm ros -l scripts/tui.lisp
```

Same GGUF family caveats as the demo (`vllm-cpp` overlay; Qwen3.5-class GGUF).

## MCP server

Same sandbox as the agent (`LLM_TUI_ROOT` or cwd). Tools: `list_dir`, `read_file` (32KiB), `write_note`, `search_files`.

```bash
LLM_TUI_ROOT=$PWD ros -l scripts/mcp-server.lisp
```

Cursor / Claude Desktop:

```json
{
  "mcpServers": {
    "llm-tui-workspace": {
      "command": "ros",
      "args": ["-l", "/ABS/cl-stack-llm-tui/scripts/mcp-server.lisp"],
      "env": { "LLM_TUI_ROOT": "/ABS/your-workspace" }
    }
  }
}
```

## Env

| Variable | Meaning |
|----------|---------|
| `LLM_TUI_BACKEND` | `lmstudio` (default) / `mock` / `vllm` |
| `LLM_TUI_LINE` | set → line mode even on a tty |
| `LLM_TUI_ROOT` | sandbox root for file tools + MCP |
| `OPENAI_BASE_URL` / `LM_STUDIO_BASE_URL` | default `http://127.0.0.1:1234/v1` |
| `OPENAI_MODEL` / `LM_STUDIO_MODEL` | default `local-model` |
| `OPENAI_API_KEY` / `LM_API_TOKEN` | only if LM Studio “Require authentication” is on (`sk-lm-…`; dummy `lm-studio` rejected) |
| `LLM_TUI_ENV` | path to a `.env` (otherwise cwd / checkout / parent workspace) |
| `VLLM_MODEL_PATH` | GGUF for `/vllm` |
| `CL_REPOSITORY_CLIENT_DIR` | already-extracted client tree |

Part of [cl-stack](https://github.com/egao1980/cl-stack).

## License

MIT — see [LICENSE](LICENSE).
