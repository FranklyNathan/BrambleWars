use axum::extract::{ws::{self, WebSocket}, WebSocketUpgrade};
use axum::{routing::get, Router};
use BrambleWarsServer::websocket_handler::handler;

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/ws", get(handler));

    let listener = tokio::net::TcpListener::bind("100.76.15.33:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
