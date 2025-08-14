use std::sync::Arc;

use axum::extract::{ws::{WebSocket, WebSocketUpgrade}, State};
use axum::response::Response;
use uuid::{ContextV7, Timestamp, Uuid};
use crate::message_handler::message_handler;
use crate::ServerState;

pub async fn handler(State(state): State<Arc<ServerState>>, ws: WebSocketUpgrade) -> Response {
    let timestamp = Timestamp::now(&state.uuid_context);
    let client_id = Uuid::new_v7(timestamp);
    ws.on_upgrade(move |socket| handle_socket(socket, client_id))
}

async fn handle_socket(mut socket: WebSocket, client_id: uuid::Uuid) {
    while let Some(message) = socket.recv().await {
        let Ok(message) = message else {
            eprintln!("Recieved error message from socket: {:?}", message);
            return;
        };

        dbg!(&message);
        message_handler(&mut socket, &message, client_id).await;
    }
}
