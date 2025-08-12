use crate::bramble::{self, envelope::Message, auction::Action};
use crate::{Auction, auction_utils::*};
use axum::extract::ws::{self, WebSocket};
use prost::Message as Msg;


pub async fn auction_handler(socket: &mut WebSocket, request: bramble::Auction)
    -> Result <(), ()>
{
    dbg!(&request);
    match request.action {
        Some(Action::HostAuction(host_auction)) => {
            host_handler(socket, host_auction).await;
        },
        _ => todo!()
    }

    Ok(())
}

async fn host_handler(socket: &mut WebSocket, _host_auction: bramble::HostAuction)
    -> Result <(), ()>
{
    let auction_action = bramble::HostAuction {
        auction_id:  "auction id".to_string(),
    };

    let auction_message = bramble::Auction {
        action: Some(Action::HostAuction(auction_action)),
    };

    let envelope = bramble::Envelope {
        message: Some(Message::Auction(auction_message)),
    };

    let mut response_bin = Vec::new();
    envelope.encode(&mut response_bin).unwrap();

    if socket.send(ws::Message::binary(response_bin)).await.is_err() {
        return Err(());
    }

    Ok(())
}
