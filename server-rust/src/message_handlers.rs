use crate::bramble;
use crate::bramble::envelope::MessageType;
use axum::extract::ws::{self, WebSocket};
use prost::Message;

pub async fn echo_handler(socket: &mut WebSocket, request: bramble::EchoMessage) -> Result<(), ()> {
    println!("Received echo from client: {}", request.message);
    let response = bramble::EchoMessage {
        message: request.message.to_string(),
    };

    let resonse_envelope = bramble::Envelope {
        message_type: Some(MessageType::EchoMessage(response)),
    };

    let mut response_bin = Vec::new();
    resonse_envelope.encode(&mut response_bin).unwrap();

    if socket.send(ws::Message::binary(response_bin)).await.is_err() {
        return Err(());
    }

    Ok(())
}
