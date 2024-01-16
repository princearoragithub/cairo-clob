// @title CLOB Cairo
// @author Prince Arora
// @license MIT
// @dev Converted from python
//  https://github.com/dyn4mik3/OrderBook

use cairo_clob::data_structures::{Quote, Order, OrderList, TradingParty, TransactionRecord};

//
// Contract Interface
//
#[starknet::interface]
trait IOrderBook<TContractState> {
    // view functions
    fn get_best_bid(self: @TContractState) -> u128;
    fn get_best_ask(self: @TContractState) -> u128;
    fn get_volume_at_price(self: @TContractState, side: felt252, price: u128) -> u256;
    // external functions
    fn process_order(ref self: TContractState, input_quote: Quote) -> (Array<TransactionRecord>, Quote);
    fn cancel_order(ref self: TContractState, side: felt252, order_id: u32);
    fn modify_order(ref self: TContractState, order_id: u32, order_update: Quote);
}

#[starknet::contract]
mod OrderBook {
    use core::array::ArrayTrait;
    use starknet::get_block_info;
    use cairo_clob::data_structures::{Quote, Order, OrderList, TradingParty, TransactionRecord};
    use cairo_clob::Order::OrderTrait;
    use cairo_clob::OrderList::OrderListTrait;
    use cairo_clob::OrderTrees::OrderTrees;

    //
    // Storage Pair
    //
    #[storage]
    struct Storage {
        _next_order_id: u32, // @dev Will start with 1
    }

    //
    // Constructor
    //

    // @notice Contract constructor
    #[constructor]
    fn constructor(ref self: ContractState) {
        self._next_order_id.write(1);
    }

    #[external(v0)]
    impl OrderBook of super::IOrderBook<ContractState> {
        
        fn get_best_bid(self: @ContractState) -> u128 {
            InternalImpl::_get_best_bid(self)
        }

        fn get_best_ask(self: @ContractState) -> u128 {
            InternalImpl::_get_best_ask(self)
        }

        fn get_volume_at_price(self: @ContractState, side: felt252, price: u128) -> u256 {
            InternalImpl::_get_volume_at_price(self, side, price)
        }
        
        fn process_order(ref self: ContractState, input_quote: Quote) -> (Array<TransactionRecord>, Quote) {
            InternalImpl::_process_order(ref self, input_quote)
        }

        fn cancel_order(ref self: ContractState, side: felt252, order_id: u32) {
            InternalImpl::_cancel_order(ref self, side, order_id)
        }

        fn modify_order(ref self: ContractState, order_id: u32, order_update: Quote) {
            InternalImpl::_modify_order(ref self, order_id, order_update)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        ///
        /// Internals
        ///

        fn _get_best_bid(self: @ContractState) -> u128 {
            let order_trees_state = OrderTrees::unsafe_new_contract_state();
            OrderTrees::InternalImpl::_get_max_price(@order_trees_state, 'bid')
        }

        fn _get_worst_bid(self: @ContractState) -> u128 {
            let order_trees_state = OrderTrees::unsafe_new_contract_state();
            OrderTrees::InternalImpl::_get_min_price(@order_trees_state, 'bid')
        }

        fn _get_best_ask(self: @ContractState) -> u128 {
            let order_trees_state = OrderTrees::unsafe_new_contract_state();
            OrderTrees::InternalImpl::_get_min_price(@order_trees_state, 'ask')
        }

        fn _get_worst_ask(self: @ContractState) -> u128 {
            let order_trees_state = OrderTrees::unsafe_new_contract_state();
            OrderTrees::InternalImpl::_get_max_price(@order_trees_state, 'ask')
        }

        fn _get_volume_at_price(self: @ContractState, side: felt252, price: u128) -> u256 {
            assert(side == 'bid' || side == 'ask', 'invalid side');
            let mut volume = 0;
            let order_trees_state = OrderTrees::unsafe_new_contract_state();
            if (OrderTrees::InternalImpl::_price_exists(@order_trees_state, side, price)) {
                let order_list = OrderTrees::InternalImpl::_get_price_list(@order_trees_state, side, price);
                volume = order_list.get_volume();
            }
            volume
        }

        fn _process_order(ref self: ContractState, input_quote: Quote) -> (Array<TransactionRecord>, Quote) {
            let mut quote = input_quote;
            let order_type = quote.order_type;
            quote.block_number = get_block_info().unbox().block_number;
            assert(quote.quantity > 0, '0 quantity');
            quote.order_id = self._next_order_id.read();
            self._next_order_id.write(quote.order_id + 1);
            assert(order_type == 'm' || order_type == 'l', 'invalid order type');
            if (order_type == 'm') {
                return (InternalImpl::_process_market_order(ref self, quote), Quote {order_id: 0, order_type: 0, side: 0, block_number: 0, quantity: 0, price: 0, trade_id: 0});
            } else {
                return InternalImpl::_process_limit_order(ref self, quote);
            }
        }

        fn _process_order_list(ref self: ContractState, side: felt252, order_list_price: u128, quantity_still_to_trade: u256, quote: Quote) -> (u256, Array::<TransactionRecord>) {
            // Takes an OrderList (stack of orders at one price) and an incoming order and matches
            // appropriate trades given the order's quantity.
            let mut trades = ArrayTrait::<TransactionRecord>::new();
            let mut quantity_to_trade = quantity_still_to_trade;
            let mut order_trees_state = OrderTrees::unsafe_new_contract_state();
            let mut order_list = OrderTrees::InternalImpl::_get_price_list(@order_trees_state, side, order_list_price);
            let mut opposite_side = 'bid';
            if (side == 'bid') {
                opposite_side = 'ask';
            }
            loop {
                if (quantity_to_trade == 0 || order_list.length == 0) {
                    break true;
                }
                let head_order = OrderTrees::InternalImpl::_get_order(@order_trees_state, side, order_list.get_head_order_id());
                let traded_price = head_order.price;
                let counter_party = head_order.trade_id;
                let mut new_head_quantity = 0;
                let mut traded_quantity = 0;

                if (quantity_to_trade < head_order.quantity) {
                    traded_quantity = quantity_to_trade;
                    new_head_quantity = head_order.quantity - quantity_to_trade;
                    let prev_order = OrderTrees::InternalImpl::_get_order(@order_trees_state, side, head_order.prev_order_id);
                    let next_order = OrderTrees::InternalImpl::_get_order(@order_trees_state, side, head_order.next_order_id);
                    let tail_order = OrderTrees::InternalImpl::_get_order(@order_trees_state, side, order_list.tail_order_id);
                    let (moved_to_tail, updated_order, updated_order_list, updated_prev_order, updated_next_order, updated_tail_order) = head_order.update_quantity(new_head_quantity, head_order.block_number, @order_list, @prev_order, @next_order, @tail_order);
                    OrderTrees::InternalImpl::_set_price_list(ref order_trees_state, side, head_order.price, updated_order_list);
                    if (moved_to_tail) {
                        let mut order_ids = ArrayTrait::<u32>::new();
                        order_ids.append(head_order.order_id);
                        order_ids.append(prev_order.order_id);
                        order_ids.append(next_order.order_id);
                        order_ids.append(tail_order.order_id);
                        let mut updated_orders = ArrayTrait::<Order>::new();
                        updated_orders.append(updated_order);
                        updated_orders.append(updated_prev_order);
                        updated_orders.append(updated_next_order);
                        updated_orders.append(updated_tail_order);
                        OrderTrees::InternalImpl::_set_4_orders(ref order_trees_state, side, order_ids, updated_orders);
                    } else {
                        OrderTrees::InternalImpl::_set_order(ref order_trees_state, side, head_order.order_id, updated_order);
                    }
                    quantity_to_trade = 0;
                } else if (quantity_to_trade == head_order.quantity) {
                    traded_quantity = quantity_to_trade;
                    OrderTrees::InternalImpl::_remove_order_by_id(ref order_trees_state, side, head_order.order_id);
                    quantity_to_trade = 0;
                } else { 
                    traded_quantity = head_order.quantity;
                    OrderTrees::InternalImpl::_remove_order_by_id(ref order_trees_state, side, head_order.order_id);
                    quantity_to_trade -= traded_quantity;
                }
                
                let transaction_record = TransactionRecord {block_number: get_block_info().unbox().block_number, price: traded_price, quantity: traded_quantity, party_1: TradingParty{trade_id: counter_party, side: side, order_id: head_order.order_id, new_head_quantity: new_head_quantity}, party_2: TradingParty {trade_id: quote.trade_id, side: opposite_side, order_id: 0, new_head_quantity: 0} };
                trades.append(transaction_record);
                order_list = OrderTrees::InternalImpl::_get_price_list(@order_trees_state, side, order_list_price);
            };

            (quantity_to_trade, trades)
        }

        fn _concat_arrays(array_1: Array::<TransactionRecord>, array_2: Array::<TransactionRecord>) -> Array<TransactionRecord> {
            let mut final_array = ArrayTrait::<TransactionRecord>::new();
            let len_array_1 = array_1.len();
            let mut current_index = 0;
            loop {
                if (current_index == len_array_1) {
                    break true;
                }
                final_array.append(*array_1[current_index]);
                current_index += 1;
            };
            let len_array_2 = array_2.len();
            current_index = 0;
            loop {
                if (current_index == len_array_2) {
                    break true;
                }
                final_array.append(*array_2[current_index]);
                current_index += 1;
            };
            final_array
        }

        fn _process_market_order(ref self: ContractState, quote: Quote) -> Array<TransactionRecord> {
            let mut trades = ArrayTrait::<TransactionRecord>::new();
            let mut quantity_to_trade = quote.quantity;
            let side = quote.side;
            assert(side == 'bid' || side == 'ask', 'invalid side');
            let mut opposite_side = 'bid';
            if (side == 'bid') {
                opposite_side = 'ask';
            }
            let mut order_trees_state = OrderTrees::unsafe_new_contract_state();
            let total_volume_available = OrderTrees::InternalImpl::_get_volume(@order_trees_state, opposite_side);
            assert (total_volume_available >= quantity_to_trade, 'volume high');
            if (side == 'bid') {
                loop {
                    let num_orders = OrderTrees::InternalImpl::_get_num_orders(@order_trees_state, 'ask');
                    if (quantity_to_trade <= 0 || num_orders <= 0) {
                        break true;
                    }
                    let (new_quantity_to_trade, new_trades) = InternalImpl::_process_order_list(ref self, 'ask', InternalImpl::_get_best_ask(@self), quantity_to_trade, quote);
                    quantity_to_trade = new_quantity_to_trade;
                    trades = InternalImpl::_concat_arrays(trades, new_trades);
                };
            } else if (side == 'ask') {
                loop {
                    let num_orders = OrderTrees::InternalImpl::_get_num_orders(@order_trees_state, 'bid');
                    if (quantity_to_trade <= 0 || num_orders <= 0) {
                        break true;
                    }
                    let (new_quantity_to_trade, new_trades) = InternalImpl::_process_order_list(ref self, 'bid', InternalImpl::_get_best_bid(@self), quantity_to_trade, quote);
                    quantity_to_trade = new_quantity_to_trade;
                    trades = InternalImpl::_concat_arrays(trades, new_trades);
                };
            }

            trades
        }

        fn _process_limit_order(ref self: ContractState, mut quote: Quote) -> (Array<TransactionRecord>, Quote) {
            let mut order_in_book = Quote {order_id: 0, order_type: 0, side: 0, block_number: 0, quantity: 0, price: 0, trade_id: 0};
            let mut trades = ArrayTrait::<TransactionRecord>::new();
            let mut quantity_to_trade = quote.quantity;
            let side = quote.side;
            let price = quote.price;
            assert(side == 'bid' || side == 'ask', 'invalid side');
            if (side == 'bid') {
                loop {
                    let order_trees_state = OrderTrees::unsafe_new_contract_state();
                    let num_orders = OrderTrees::InternalImpl::_get_num_orders(@order_trees_state, 'ask');
                    let best_ask_price = InternalImpl::_get_best_ask(@self);
                    if (quantity_to_trade <= 0 || num_orders <= 0 || price < best_ask_price) {
                        break true;
                    }
                    let (new_quantity_to_trade, new_trades) = InternalImpl::_process_order_list(ref self, 'ask', InternalImpl::_get_best_ask(@self), quantity_to_trade, quote);
                    quantity_to_trade = new_quantity_to_trade;
                    trades = InternalImpl::_concat_arrays(trades, new_trades);
                };
                if (quantity_to_trade > 0) {
                    // quote.order_id = self._next_order_id.read();
                    // self._next_order_id.write(quote.order_id + 1);
                    quote.quantity = quantity_to_trade;
                    let mut order_trees_state = OrderTrees::unsafe_new_contract_state();
                    OrderTrees::InternalImpl::_insert_order(ref order_trees_state, 'bid', quote);
                    order_in_book = quote;
                }
            } else if (side == 'ask') {
                loop {
                    let order_trees_state = OrderTrees::unsafe_new_contract_state();
                    let num_orders = OrderTrees::InternalImpl::_get_num_orders(@order_trees_state, 'bid');
                    let best_bid_price = InternalImpl::_get_best_bid(@self);
                    if (quantity_to_trade <= 0 || num_orders <= 0 || price > best_bid_price) {
                        break true;
                    }
                    let (new_quantity_to_trade, new_trades) = InternalImpl::_process_order_list(ref self, 'bid', InternalImpl::_get_best_bid(@self), quantity_to_trade, quote);
                    quantity_to_trade = new_quantity_to_trade;
                    trades = InternalImpl::_concat_arrays(trades, new_trades);
                };
                if (quantity_to_trade > 0) {
                    // quote.order_id = self._next_order_id.read();
                    // self._next_order_id.write(quote.order_id + 1);
                    quote.quantity = quantity_to_trade;
                    let mut order_trees_state = OrderTrees::unsafe_new_contract_state();
                    OrderTrees::InternalImpl::_insert_order(ref order_trees_state, 'ask', quote);
                    order_in_book = quote;
                }
            }

            (trades, order_in_book)
        }

        fn _cancel_order(ref self: ContractState, side: felt252, order_id: u32) {
            assert(side == 'bid' || side == 'ask', 'invalid side');
            let mut order_trees_state = OrderTrees::unsafe_new_contract_state();
            if (OrderTrees::InternalImpl::_order_exists(@order_trees_state, side, order_id)) {
                OrderTrees::InternalImpl::_remove_order_by_id(ref order_trees_state, side, order_id);
            }
        }

        fn _modify_order(ref self: ContractState, order_id: u32, order_update: Quote) {
            let side = order_update.side;
            assert(side == 'bid' || side == 'ask', 'invalid side');
            let mut mutable_order_update = order_update;
            mutable_order_update.order_id = order_id;
            mutable_order_update.block_number = get_block_info().unbox().block_number;
            let mut order_trees_state = OrderTrees::unsafe_new_contract_state();
            if (OrderTrees::InternalImpl::_order_exists(@order_trees_state, side, order_id)) {
                OrderTrees::InternalImpl::_update_order(ref order_trees_state, side, mutable_order_update);
            }
        }
    }
}