use BrambleWarsServer::bramble::{self, envelope::MessageType};
use BrambleWarsServer::message_handlers::*;
use prost::Message;
use axum::extract::{ws::{self, WebSocket}, WebSocketUpgrade};
use axum::{response::Response, routing::get, Router};

async fn handler(ws: WebSocketUpgrade) -> Response {
    ws.on_upgrade(handle_socket)
}

async fn handle_socket(mut socket: WebSocket) {
    while let Some(message) = socket.recv().await {
        let Ok(message) = message else {
            eprintln!("Recieved error message from socket: {:?}", message);
            return;
        };

        dbg!(&message);


        match message {
            ws::Message::Binary(ref binary_msg) => {
                let proto_msg = bramble::Envelope::decode(&binary_msg[..]).expect("Couldn't decode binary message");
                match proto_msg.message_type {
                    Some(MessageType::EchoMessage(request)) => {
                        if echo_handler(&mut socket, request).await.is_err() {
                            return;
                        }
                    }
                    Some(MessageType::HeartbeatMessage(request)) => {
                        if heartbeat_handler(&mut socket, request).await.is_err() {
                            return;
                        }
                    }
                    None => eprintln!("Unhandled message recieved"),
                };
            },
            ws::Message::Close(_) => println!("Socket Closed"),
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
        .route("/ws", get(handler));

    let listener = tokio::net::TcpListener::bind("100.76.15.33:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
