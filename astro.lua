import asyncio, re, httpx
from fastapi import FastAPI, Request, WebSocket
from fastapi.responses import Response
from websockets.asyncio.client import connect
app = FastAPI()
@app.websocket("/{path:path}")
async def ws(client: WebSocket, path: str):
    try:
        proxy = await connect(f"wss://www.astatine.vip/{path}" + (f"?{client.url.query}" if client.url.query else ""),
                user_agent_header=client.headers.get("user-agent", "Mozilla/5.0"))
    except Exception:
        return await client.close(code=1011)
    await client.accept()
    async def a():
        while (msg := await client.receive())["type"] != "websocket.disconnect":
            await proxy.send(msg["text"] if msg.get("text") is not None else msg["bytes"])
    async def b():
        async for msg in proxy:
            await (client.send_text(msg) if isinstance(msg, str) else client.send_bytes(msg))
    tasks = [asyncio.create_task(a()), asyncio.create_task(b())]
    await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
    for t in tasks:
        t.cancel()
    await proxy.close()
    try:
        await client.close()
    except Exception:
        pass

@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"])
async def proxy(request: Request, path: str):
    host = request.headers["host"]
    headers = {**request.headers, "host": "www.astatine.vip", "accept-encoding": "gzip"}
    async with httpx.AsyncClient(timeout=30) as c:
        r = await c.request(request.method,
            f"https://www.astatine.vip/{path}" + (f"?{request.url.query}" if request.url.query else ""),
            headers= headers, 
            content= await request.body() or None
        )
    content = r.content
    if path == "scripts/all_in_one.lua":
        content = f'proxy="{request.url.scheme}://{host}/scripts/";\n'.encode() + content
    if any(t in r.headers.get("content-type", "") for t in ("text/html", "text/css", "javascript", "application/json")):
        content = content.replace(b"//www.astatine.vip", f"//{host}".encode())
    return Response(content, r.status_code)
