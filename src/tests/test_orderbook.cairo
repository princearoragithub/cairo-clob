use core::array::ArrayTrait;
use cairo_clob::data_structures::{Quote, Order, OrderList, TradingParty, TransactionRecord};
use snforge_std::{ declare, ContractClassTrait , PrintTrait};

#[starknet::interface]
trait IOrderBook<T> {
    // view functions
    fn get_best_bid(self: @T) -> u128;
    fn get_best_ask(self: @T) -> u128;
    fn get_volume_at_price(self: @T, side: felt252, price: u128) -> u256;
    // external functions
    fn process_order(ref self: T, input_quote: Quote) -> (Array<TransactionRecord>, Quote);
    fn cancel_order(ref self: T, side: felt252, order_id: u32);
    fn modify_order(ref self: T, order_id: u32, order_update: Quote);
}

#[test]
#[available_gas(20000000000)]
fn test_orders() { // TODO Separate out once setup is available.
    
    let orderbook_class = declare('OrderBook');
    let orderbook_address = orderbook_class.deploy(@ArrayTrait::new()).unwrap();

    let orderbook_dispatcher = IOrderBookDispatcher { contract_address: orderbook_address };

    let mut limit_orders = ArrayTrait::<Quote>::new();
    let mut current_index = 0;
    let mut price_index = 1;
    let mut trade_id_index = 0;
    loop {
        if (current_index == 100) {
            break true;
        }
        limit_orders.append(Quote {order_id: 0, order_type: 'l', side: 'ask', block_number: 0, quantity: 5, price: 1000000 + price_index, trade_id: 10000000 + trade_id_index});
        limit_orders.append(Quote {order_id: 0, order_type: 'l', side: 'bid', block_number: 0, quantity: 5, price: 1000000 - price_index, trade_id: 20000000 + trade_id_index});

        current_index += 1;
        price_index += 1;
        trade_id_index += 1;
    };

    current_index = 0;
    loop {
        if (current_index == limit_orders.len()) {
            break true;
        }
        let limit_order = *limit_orders[current_index];
        let (trades, order_in_book) = orderbook_dispatcher.process_order(limit_order);
        current_index += 1;
    };

    orderbook_dispatcher.get_best_bid().print();
    orderbook_dispatcher.get_best_ask().print();

    let crossing_limit_order = Quote {order_id: 0, order_type: 'l', side: 'bid', block_number: 0, quantity: 2, price: 1000002, trade_id: 30000000 + trade_id_index};
    trade_id_index += 1;
    let (trades, order_in_book) = orderbook_dispatcher.process_order(crossing_limit_order);
    orderbook_dispatcher.get_best_bid().print();
    orderbook_dispatcher.get_best_ask().print();
    order_in_book.quantity.print();
    'trades'.print();
    trades.len().print();
    current_index = 0;
    loop {
        if (current_index == trades.len()) {
            break true;
        }
        let trade: TransactionRecord = *trades[current_index];
        trade.block_number.print();
        trade.price.print();
        trade.quantity.print();
        trade.party_1.trade_id.print();
        trade.party_1.order_id.print();
        trade.party_1.side.print();
        trade.party_1.new_head_quantity.print();
        trade.party_2.trade_id.print();
        trade.party_2.order_id.print();
        trade.party_2.side.print();
        trade.party_2.new_head_quantity.print();
        current_index += 1;
    };

    let big_crossing_limit_order = Quote {order_id: 0, order_type: 'l', side: 'bid', block_number: 0, quantity: 50, price: 1000002, trade_id: 30000000 + trade_id_index};
    trade_id_index += 1;
    let (trades, order_in_book) = orderbook_dispatcher.process_order(big_crossing_limit_order);
    orderbook_dispatcher.get_best_bid().print();
    orderbook_dispatcher.get_best_ask().print();
    orderbook_dispatcher.get_volume_at_price('ask', 101).print();
    order_in_book.quantity.print();
    'trades'.print();
    trades.len().print();
    current_index = 0;
    loop {
        if (current_index == trades.len()) {
            break true;
        }
        let trade: TransactionRecord = *trades[current_index];
        trade.block_number.print();
        trade.price.print();
        trade.quantity.print();
        trade.party_1.trade_id.print();
        trade.party_1.order_id.print();
        trade.party_1.side.print();
        trade.party_1.new_head_quantity.print();
        trade.party_2.trade_id.print();
        trade.party_2.order_id.print();
        trade.party_2.side.print();
        trade.party_2.new_head_quantity.print();
        current_index += 1;
    };

    let market_order = Quote {order_id: 0, order_type: 'm', side: 'ask', block_number: 0, quantity: 55, price: 0, trade_id: 30000000 + trade_id_index};
    trade_id_index += 1;
    let (trades, order_in_book) = orderbook_dispatcher.process_order(market_order);
    orderbook_dispatcher.get_best_bid().print();
    orderbook_dispatcher.get_best_ask().print();
    orderbook_dispatcher.get_volume_at_price('ask', 101).print();
    order_in_book.quantity.print();
    'trades'.print();
    trades.len().print();
    current_index = 0;
    loop {
        if (current_index == trades.len()) {
            break true;
        }
        let trade: TransactionRecord = *trades[current_index];
        trade.block_number.print();
        trade.price.print();
        trade.quantity.print();
        trade.party_1.trade_id.print();
        trade.party_1.order_id.print();
        trade.party_1.side.print();
        trade.party_1.new_head_quantity.print();
        trade.party_2.trade_id.print();
        trade.party_2.order_id.print();
        trade.party_2.side.print();
        trade.party_2.new_head_quantity.print();
        current_index += 1;
    };
}