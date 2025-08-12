use crate::{bramble, auction_handler};
use crate::bramble::envelope::Message;
use axum::extract::ws::{self, WebSocket};
use prost::Message as Msg;

pub async fn message_handler(socket: &mut WebSocket, message: &ws::Message) {
    match message {
        ws::Message::Binary(binary_msg) => {
            let envelope = bramble::Envelope::decode(&binary_msg[..]).expect("Couldn't decode binary message");
            match envelope.message {
                Some(Message::EchoMessage(request)) => {
                    if echo_handler(socket, request).await.is_err() {
                        eprintln!("Failed to handle Echo message");
                        return;
                    }
                }
                Some(Message::HeartbeatMessage(request)) => {
                    if heartbeat_handler(socket, request).await.is_err() {
                        eprintln!("Failed to handle Heartbeat message");
                        return;
                    }
                }
                Some(Message::Auction(request)) => {
                    if auction_handler(socket, request).await.is_err() {
                        eprintln!("Failed to handle Auction message");
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

async fn echo_handler(socket: &mut WebSocket, request: bramble::EchoMessage)
    -> Result<(), ()>
{
    dbg!(&request);
    let response = bramble::EchoMessage {
        message: request.message.to_string(),
    };

    let response_envelope = bramble::Envelope {
        message: Some(Message::EchoMessage(response)),
    };

    let mut response_bin = Vec::new();
    response_envelope.encode(&mut response_bin).unwrap();

    if socket.send(ws::Message::binary(response_bin)).await.is_err() {
        return Err(());
    }

    Ok(())
}

async fn heartbeat_handler(socket: &mut WebSocket, request: bramble::HeartbeatMessage)
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
        message: Some(Message::HeartbeatMessage(response))
    };

    let mut response_bin = Vec::new();
    response_envelope.encode(&mut response_bin).unwrap();

    if socket.send(ws::Message::binary(response_bin)).await.is_err() {
        return Err(());
    }

    Ok(())
}

