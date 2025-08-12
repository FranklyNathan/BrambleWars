use std::{collections::HashMap, time::Duration};
use axum::extract::ws::WebSocket;
use tokio::time::Instant;

use crate::bramble::AuctionState;

pub mod message_handler;
pub mod websocket_handler;
pub mod auction_utils;
mod auction_handler;
pub use auction_handler::auction_handler;

pub mod bramble {
    include!(concat!(env!("OUT_DIR"), "/bramble.rs"));
}

pub struct Lot {
    items: Box<[u32]>,
    highest_bid: u32,
}

pub struct Auction<'a> {
    host: &'a WebSocket,
    current_lot: Lot,
    remaining_lots: Vec<Lot>,
    start_time: Instant,
    current_countdown: Duration,
    state: AuctionState,
}

pub struct ServerState<'a> {
    auctions: HashMap<u32, Auction<'a>>,
}
