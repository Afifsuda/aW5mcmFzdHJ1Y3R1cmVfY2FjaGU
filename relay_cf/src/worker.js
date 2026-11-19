import { DurableObject } from "cloudflare:workers";

export class VoiceRoom extends DurableObject {
  async fetch(request) {
    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("Antigravity Cloudflare Relay Ready", { status: 200 });
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    this.ctx.acceptWebSocket(server);

    return new Response(null, {
      status: 101,
      webSocket: client,
    });
  }

  async webSocketMessage(ws, message) {
    for (const peer of this.ctx.getWebSockets()) {
      if (peer !== ws) {
        try {
          peer.send(message);
        } catch {
          // Ignore closed peers
        }
      }
    }
  }

  async webSocketClose(ws, code, reason) {
    try {
      ws.close(code, reason);
    } catch {
      // Ignore
    }
  }

  async webSocketError(ws) {
    try {
      ws.close(1011, "WebSocket error");
    } catch {
      // Ignore
    }
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("Antigravity Cloudflare Relay Ready\n", {
        status: 200,
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

    const roomName = (url.searchParams.get("room") || "default").trim();
    const id = env.ROOM.idFromName(roomName);
    const stub = env.ROOM.get(id);
    return stub.fetch(request);
  },
};
