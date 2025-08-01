use prost::Message;
use axum::extract::{ws::{self, WebSocket}, WebSocketUpgrade};
use axum::{response::Response, routing::any, Router};

pub mod bramble {
    include!(concat!(env!("OUT_DIR"), "/bramble.rs"));
}

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
           ws::Message::Text(ref msg) => {
               println!("{}", msg);

               let msg = bramble::EchoMessage {
                   message: msg.to_string(),
               };
               
               let mut message_buf = Vec::new();
               msg.encode(&mut message_buf).unwrap();

               if socket.send(ws::Message::binary(message_buf)).await.is_err() {
                   return;
               }
           }
            ws::Message::Close(ref msg) => println!("Socket Closed: {:?}", msg),
            _ => println!("non text msg recieved"),
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
