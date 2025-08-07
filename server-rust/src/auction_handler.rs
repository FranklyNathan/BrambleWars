use crate::bramble::{self, envelope::Message, auction::Action};
use axum::extract::ws::WebSocket;

pub async fn auction_handler(socket: &mut WebSocket, request: bramble::Auction)
    -> Result <(), ()>
{
    dbg!(&request);
    match request.action {
        Some(Action::HostAuction(host_auction)) => {
            host_handler(socket, host_auction);
        },
        _ => todo!()
    }

    Ok(())
}

async fn host_handler(socket: &mut WebSocket, host_auction: bramble::HostAuction) 
    -> Result <(), ()>
{

    Ok(())
}
