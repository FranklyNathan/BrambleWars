use std::sync::Arc;
use axum::extract::{ws::{self, WebSocket}, WebSocketUpgrade};
use axum::{routing::any, Router};
use BrambleWarsServer::{websocket_handler::handler, ServerState};

#[tokio::main]
async fn main() {
    let state = Arc::new(ServerState { 
        auctions: Vec::new(),
        uuid_context: uuid::ContextV7::new(),
    });

    let app = Router::new()
        .route("/ws", any(handler))
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("100.76.15.33:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
