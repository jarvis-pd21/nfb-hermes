"""NFB guard: the last step before any reply leaves an NFB AI agent's computer.

1. Copy locks (Phil): never "tradeable intelligence", "asset class", "treasury", "hire", "profit", "returns".
   Each is swapped for plain words ("earn", "pay its bills" spirit). Deterministic, so it can't fail open.
2. Secrets: anything shaped like an API key or private key is redacted (the computer holds no phone or payment
   secrets by design; this is a second lock).
"""
import re

_SWAPS = [
    (r"\btradeable intelligence\b", "AI agents"),
    (r"\basset class(es)?\b", "kind of thing"),
    (r"\btreasur(y|ies)\b", "wallet"),
    (r"\bhiring\b", "bringing on"),
    (r"\bhired\b", "brought on"),
    (r"\bhires\b", "brings on"),
    (r"\bhire\b", "work with"),
    (r"\bprofitable\b", "able to pay its bills"),
    (r"\bprofits?\b", "earnings"),
    (r"\breturns\b", "earnings"),
]
_SECRETS = re.compile(r"(sk-ant-[A-Za-z0-9_\-]{10,}|nfb[abk]_[0-9a-f]{24,}|e2b_[A-Za-z0-9]{10,}|sk_(test|live)_[A-Za-z0-9]{10,}|0x[0-9a-fA-F]{64})")


def _keep_case(src: str, dst: str) -> str:
    return dst[:1].upper() + dst[1:] if src[:1].isupper() else dst


def clean(text: str) -> str:
    out = text
    for pat, rep in _SWAPS:
        out = re.sub(pat, lambda m, r=rep: _keep_case(m.group(0), r), out, flags=re.IGNORECASE)
    return _SECRETS.sub("[hidden]", out)


def _transform(response_text: str = "", **_kw):
    if not response_text:
        return None
    fixed = clean(response_text)
    return fixed if fixed != response_text else None


def register(ctx):
    ctx.register_hook("transform_llm_output", _transform)
