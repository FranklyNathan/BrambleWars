pub mod message_handler;
pub mod websocket_handler;
pub mod auction_handler;

pub mod bramble {
    include!(concat!(env!("OUT_DIR"), "/bramble.rs"));
}

pub struct ServerState {
    
}
