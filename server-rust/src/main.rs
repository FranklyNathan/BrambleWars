use axum::{extract::{ws::{Message, WebSocket}, WebSocketUpgrade}, response::Response, routing::any, Router};

async fn handler(ws: WebSocketUpgrade) -> Response {
    dbg!("handling connection");
    ws.on_upgrade(handle_socket)
}

async fn handle_socket(mut socket: WebSocket) {
    while let Some(msg) = socket.recv().await {
        let msg = if let Ok(msg) = msg {
            msg
        } else {
            return;
        };

        match msg {
            Message::Text(ref msg) => println!("{}", msg),
            Message::Close(ref msg) => println!("Socket Closed: {:?}", msg),
            _ => println!("non text msg recieved"),
        }

        if socket.send(msg).await.is_err() {
            return;
        }
    }
}



#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/ws", any(handler));

    let listener = tokio::net::TcpListener::bind("localhost:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
