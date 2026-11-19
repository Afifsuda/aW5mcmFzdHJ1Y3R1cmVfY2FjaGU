import http from "node:http";
import { WebSocketServer, WebSocket } from "ws";

const PORT = Number(process.env.PORT || 8765);
const rooms = new Map();

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
  res.end("Antigravity WebSocket Relay Ready\n");
});

const wss = new WebSocketServer({ server });

wss.on("connection", (ws, req) => {
  const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);
  const room = (url.searchParams.get("room") || "default").trim();

  let clients = rooms.get(room);
  if (!clients) {
    clients = new Set();
    rooms.set(room, clients);
  }
  clients.add(ws);

  ws.on("message", (data, isBinary) => {
    const group = rooms.get(room);
    if (!group) return;
    for (const client of group) {
      if (client !== ws && client.readyState === WebSocket.OPEN) {
        try {
          client.send(data, { binary: isBinary });
        } catch {
          // Ignore send errors on closing sockets
        }
      }
    }
  });

  const cleanup = () => {
    const group = rooms.get(room);
    if (!group) return;
    group.delete(ws);
    if (group.size === 0) {
      rooms.delete(room);
    }
  };

  ws.on("close", cleanup);
  ws.on("error", cleanup);
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Antigravity WS Relay listening on port ${PORT}`);
});
