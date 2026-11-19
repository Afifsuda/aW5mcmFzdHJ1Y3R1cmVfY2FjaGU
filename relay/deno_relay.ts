// Deploy gratis di Deno Deploy (https://dash.deno.com) — tanpa kartu kredit.
// Cukup salin isi file ini ke Playground / Project baru di Deno Deploy, lalu klik Deploy.

const rooms = new Map<string, Set<WebSocket>>();

Deno.serve((req: Request) => {
  const url = new URL(req.url);

  if (req.headers.get("upgrade")?.toLowerCase() !== "websocket") {
    return new Response("Antigravity WebSocket Relay Ready", {
      status: 200,
      headers: { "content-type": "text/plain; charset=utf-8" },
    });
  }

  const room = (url.searchParams.get("room") || "default").trim();
  const { socket, response } = Deno.upgradeWebSocket(req);

  socket.onopen = () => {
    let clients = rooms.get(room);
    if (!clients) {
      clients = new Set();
      rooms.set(room, clients);
    }
    clients.add(socket);
  };

  socket.onmessage = (event) => {
    const clients = rooms.get(room);
    if (!clients) return;
    for (const client of clients) {
      if (client !== socket && client.readyState === WebSocket.OPEN) {
        try {
          client.send(event.data);
        } catch {
          // Ignore send errors on closing sockets
        }
      }
    }
  };

  const cleanup = () => {
    const clients = rooms.get(room);
    if (!clients) return;
    clients.delete(socket);
    if (clients.size === 0) {
      rooms.delete(room);
    }
  };

  socket.onclose = cleanup;
  socket.onerror = cleanup;

  return response;
});
