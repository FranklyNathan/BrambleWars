use std::{collections::HashMap, time::Duration};
use axum::extract::ws::WebSocket;
use tokio::time::Instant;
use uuid::ContextV7;

use crate::bramble::AuctionState;

pub mod message_handler;
pub mod websocket_handler;
pub mod auction_utils;
mod auction_handler;
pub use auction_handler::auction_handler;

pub mod bramble {
    include!(concat!(env!("OUT_DIR"), "/bramble.rs"));
}

#[derive(Default)]
pub struct Lot {
    items: Box<[u32]>,
    highest_bid: u32,
}

#[derive(Default)]
pub struct Auction {
    pub host: uuid::Uuid,
    pub current_lot: Lot,
    pub remaining_lots: Vec<Lot>,
    pub current_countdown: Duration,
    pub state: AuctionState,
}

#[derive(Default)]
pub struct ServerState {
    pub auctions: HashMap<u32, Auction>,
    pub uuid_context: ContextV7,
}
