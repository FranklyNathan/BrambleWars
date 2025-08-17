use crate::bramble;
use crate::bramble::envelope::MessageType;
use axum::extract::ws::{self, WebSocket};
use prost::Message;

pub async fn echo_handler(socket: &mut WebSocket, request: bramble::EchoMessage)
    -> Result<(), ()>
{
    dbg!(&request);
    let response = bramble::EchoMessage {
        message: request.message.to_string(),
    };

    let response_envelope = bramble::Envelope {
        message_type: Some(MessageType::EchoMessage(response)),
    };

    let mut response_bin = Vec::new();
    response_envelope.encode(&mut response_bin).unwrap();

    if socket.send(ws::Message::binary(response_bin)).await.is_err() {
        return Err(());
    }

    Ok(())
}

pub async fn heartbeat_handler(socket: &mut WebSocket, request: bramble::HeartbeatMessage)
    -> Result<(), ()>
{
    dbg!(&request);
    let client_id = match &request.client_id[..] {
        "" => "client 0".to_string(),
        _ => request.client_id.clone(),
    };

    let response = bramble::HeartbeatMessage {
        client_id: client_id,
        timestamp: "test timestamp".to_string(),
    };

    let response_envelope = bramble::Envelope {
        message_type: Some(MessageType::HeartbeatMessage(response))
    };

    let mut response_bin = Vec::new();
    response_envelope.encode(&mut response_bin).unwrap();

    if socket.send(ws::Message::binary(response_bin)).await.is_err() {
        return Err(());
    }

    Ok(())
}
