use axum::extract::ws::{WebSocket, WebSocketUpgrade};
use axum::response::Response;
use crate::message_handler::message_handler;

pub async fn handler(ws: WebSocketUpgrade) -> Response {
    ws.on_upgrade(handle_socket)
}

async fn handle_socket(mut socket: WebSocket) {
    while let Some(message) = socket.recv().await {
        let Ok(message) = message else {
            eprintln!("Recieved error message from socket: {:?}", message);
            return;
        };

        dbg!(&message);
        message_handler(&mut socket, &message).await;
    }
}
