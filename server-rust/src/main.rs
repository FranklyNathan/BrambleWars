use BrambleWarsServer::bramble::{self, envelope::MessageType};
use BrambleWarsServer::message_handlers::*;
use prost::Message;
use axum::extract::{ws::{self, WebSocket}, WebSocketUpgrade};
use axum::{response::Response, routing::any, Router};

async fn handler(ws: WebSocketUpgrade) -> Response {
    dbg!("handling connection");
    ws.on_upgrade(handle_socket)
}

async fn handle_socket(mut socket: WebSocket) {
    while let Some(socket_msg) = socket.recv().await {
        let Ok(encoded_msg) = socket_msg else {
            return;
        };

        match encoded_msg {
            ws::Message::Binary(ref binary_msg) => {
                let proto_msg = bramble::Envelope::decode(&binary_msg[..]).expect("Couldn't decode binary message");
                match proto_msg.message_type {
                    Some(MessageType::EchoMessage(request)) => {
                        if echo_handler(&mut socket, request).await.is_err() {
                            return;
                        }
                    }
                    None => eprint!("Empty message recieved"),
                };
            },
            ws::Message::Close(ref encoded_msg) => println!("Socket Closed: {:?}", encoded_msg),
            _ => {
                eprintln!("non binary/close msg recieved, dropping client");
                return;
            },
        };
    }
}



#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/ws", any(handler));

    let listener = tokio::net::TcpListener::bind("localhost:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
