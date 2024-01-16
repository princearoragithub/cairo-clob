#[derive(Copy, Drop, Serde)]
struct Quote {
    #[key]
    order_id: u32,
    order_type: felt252, // 'm' or 'l'
    side: felt252, // 'bid' or 'ask'
    block_number: u64,
    quantity: u256,
    price: u128,
    trade_id: u32
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Order {
    #[key]
    order_id: u32,
    block_number: u64,
    quantity: u256,
    price: u128,
    trade_id: u32,
    next_order_id: u32,
    prev_order_id: u32
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct OrderList {
    head_order_id: u32,
    tail_order_id: u32,
    length: u32,
    volume: u256,
    last_order_id: u32
}

#[derive(Copy, Drop, Serde)]
struct TradingParty {
    trade_id: u32,
    order_id: u32,
    side: felt252,
    new_head_quantity: u256
}

#[derive(Copy, Drop, Serde)]
struct TransactionRecord {
    block_number: u64,
    price: u128,
    quantity: u256,
    party_1: TradingParty,
    party_2: TradingParty,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct RBTNode {
    parent: u128,
    left: u128,
    right: u128,
    red: bool
}