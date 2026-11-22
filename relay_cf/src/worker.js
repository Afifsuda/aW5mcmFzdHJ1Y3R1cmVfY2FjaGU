import { DurableObject } from "cloudflare:workers";

const HISTORY_KEY = "chat_history";
const MAX_HISTORY = 200;

export class VoiceRoom extends DurableObject {
  async fetch(request) {
    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("Antigravity Cloudflare Relay Ready", { status: 200 });
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    this.ctx.acceptWebSocket(server);

    try {
      const history = (await this.ctx.storage.get(HISTORY_KEY)) || [];
      if (history.length > 0) {
        server.send(JSON.stringify({ type: "history", items: history }));
      }
    } catch {
      // Ignore storage read errors
    }

    return new Response(null, {
      status: 101,
      webSocket: client,
    });
  }

  async webSocketMessage(ws, message) {
    if (typeof message === "string") {
      try {
        const data = JSON.parse(message);
        if (data && data.type === "chat" && typeof data.text === "string" && data.text.trim()) {
          const item = {
            text: data.text.trim(),
            senderId: typeof data.senderId === "string" ? data.senderId : "",
            ts: typeof data.ts === "number" ? data.ts : Date.now(),
          };
          const history = (await this.ctx.storage.get(HISTORY_KEY)) || [];
          history.push(item);
          if (history.length > MAX_HISTORY) {
            history.splice(0, history.length - MAX_HISTORY);
          }
          await this.ctx.storage.put(HISTORY_KEY, history);
        } else if (data && data.type === "clear_history") {
          await this.ctx.storage.delete(HISTORY_KEY);
        }
      } catch {
        // Ignore non-JSON text
      }
    }

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
