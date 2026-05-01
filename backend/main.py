from dotenv import load_dotenv
load_dotenv()

import json
import time
import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from routers import memory, interview, faq

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("api")

app = FastAPI(
    title="AI Agent — Interview Prep & FAQ",
    description="Stateless AI backend.",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    # Read body
    body_bytes = await request.body()
    try:
        body = json.loads(body_bytes) if body_bytes else {}
        body_str = json.dumps(body, indent=2)
    except Exception:
        body_str = body_bytes.decode(errors="replace")

    log.info("─" * 60)
    log.info(f"▶  {request.method} {request.url.path}")
    if body_str and body_str != "{}":
        log.info(f"   BODY:\n{body_str}")

    start = time.perf_counter()
    response = await call_next(request)
    elapsed = (time.perf_counter() - start) * 1000

    status = response.status_code
    icon = "✅" if status < 400 else "❌"
    log.info(f"{icon} {status}  ({elapsed:.0f}ms)")

    return response


app.include_router(memory.router)
app.include_router(interview.router)
app.include_router(faq.router)


@app.get("/health")
def health():
    return {"status": "ok", "mode": "stateless"}
