#!/usr/bin/env python3
"""Exercise real asm-lsp definition/reference requests against a NASM project."""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import tempfile
import time


def send(process: subprocess.Popen[bytes], message: dict) -> None:
    body = json.dumps(message, separators=(",", ":")).encode("utf-8")
    process.stdin.write(f"Content-Length: {len(body)}\r\n\r\n".encode("ascii"))
    process.stdin.write(body)
    process.stdin.flush()


def read_message(process: subprocess.Popen[bytes], timeout: float = 15.0) -> dict:
    deadline = time.monotonic() + timeout
    headers: dict[bytes, bytes] = {}
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("timed out waiting for asm-lsp response")
        line = process.stdout.readline()
        if not line:
            stderr = process.stderr.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"asm-lsp exited without a response:\n{stderr}")
        if line in (b"\r\n", b"\n"):
            break
        name, value = line.split(b":", 1)
        headers[name.strip().lower()] = value.strip()

    length = int(headers[b"content-length"])
    body = process.stdout.read(length)
    if len(body) != length:
        raise EOFError("truncated asm-lsp response")
    return json.loads(body.decode("utf-8"))


def response_for(process: subprocess.Popen[bytes], request_id: int) -> dict:
    while True:
        message = read_message(process)
        if message.get("id") == request_id:
            if "error" in message:
                raise RuntimeError(f"LSP request failed: {message['error']}")
            return message.get("result")
        if "method" in message and "id" in message:
            method = message["method"]
            result = [] if method == "workspace/configuration" else {}
            send(process, {"jsonrpc": "2.0", "id": message["id"], "result": result})


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} /path/to/host/asm-lsp", file=sys.stderr)
        return 2

    executable = pathlib.Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix="codexis-nasm-lsp-") as temporary:
        root = pathlib.Path(temporary)
        (root / ".git").mkdir()
        (root / ".asm-lsp.toml").write_text(
            "[default_config]\n"
            'assembler = "nasm"\n'
            'instruction_set = "x86-64"\n'
            "\n[default_config.opts]\n"
            "diagnostics = false\n"
            "default_diagnostics = false\n",
            encoding="utf-8",
        )
        source = (
            "BITS 64\nsection .text\nglobal _start\n_start:\n"
            "    call helper\n    ret\nhelper:\n    ret\n    call helper\n"
        )
        (root / "main.asm").write_text(
            source,
            encoding="utf-8",
        )
        main_uri = (root / "main.asm").as_uri()
        process = subprocess.Popen(
            [str(executable)],
            cwd=root,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        try:
            send(
                process,
                {
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "initialize",
                    "params": {
                        "processId": None,
                        "rootUri": root.as_uri(),
                        "capabilities": {},
                        "workspaceFolders": [{"uri": root.as_uri(), "name": "fixture"}],
                    },
                },
            )
            initialize = response_for(process, 1)
            assert initialize["capabilities"], "server returned no LSP capabilities"
            send(process, {"jsonrpc": "2.0", "method": "initialized", "params": {}})
            send(
                process,
                {
                    "jsonrpc": "2.0",
                    "method": "textDocument/didOpen",
                    "params": {
                        "textDocument": {
                            "uri": main_uri,
                            "languageId": "asm",
                            "version": 1,
                            "text": source,
                        }
                    },
                },
            )
            time.sleep(0.2)
            request_params = {
                "textDocument": {"uri": main_uri},
                "position": {"line": 4, "character": 11},
            }
            send(
                process,
                {
                    "jsonrpc": "2.0",
                    "id": 2,
                    "method": "textDocument/definition",
                    "params": request_params,
                },
            )
            definition = response_for(process, 2)
            assert definition, "definition request returned no target"
            locations = definition if isinstance(definition, list) else [definition]
            assert any(item.get("uri") == main_uri for item in locations), definition

            send(
                process,
                {
                    "jsonrpc": "2.0",
                    "id": 3,
                    "method": "textDocument/references",
                    "params": {
                        **request_params,
                        "context": {"includeDeclaration": True},
                    },
                },
            )
            references = response_for(process, 3)
            assert references and len(references) >= 2, references
            print(
                "PASS: asm-lsp initialized and resolved NASM definition plus references "
                f"({len(references)} same-file locations)."
            )
            return 0
        finally:
            if process.poll() is None:
                send(process, {"jsonrpc": "2.0", "id": 4, "method": "shutdown", "params": None})
                try:
                    response_for(process, 4)
                    send(process, {"jsonrpc": "2.0", "method": "exit"})
                    process.wait(timeout=3)
                except (OSError, RuntimeError, TimeoutError, EOFError):
                    process.terminate()
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        process.kill()


if __name__ == "__main__":
    raise SystemExit(main())
