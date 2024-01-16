//  A red-black tree used to store OrderLists in price order
//  The exchange will be using the OrderTree to hold bid and ask data (one OrderTree for each side).
//  Keeping the information in a red black tree makes it easier/faster to detect a match.

#[starknet::contract]
mod OrderTrees {
    use cairo_clob::data_structures::{Quote, Order, OrderList};
    use cairo_clob::Order::OrderTrait;
    use cairo_clob::OrderList::OrderListTrait;
    use cairo_clob::RedBlackTrees::RedBlackTrees;

    //
    // Storage Pair
    //
    #[storage]
    struct Storage {
        _price_map: LegacyMap::<(felt252, u128), OrderList>, // @dev Mapping from price to OrderList for each bid/ask trees
        _order_map: LegacyMap::<(felt252, u32), Order>, // @dev Mapping from order_id to orders for each bid/ask trees
        _volume: LegacyMap::<felt252, u256>, // @dev total volume in each bid/ask trees
        _num_orders: LegacyMap::<felt252, u32>, // @dev total number of orders in each bid/ask trees
        _depth: LegacyMap::<felt252, u32>, // @dev total number of different prices in each bid/ask trees
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        ///
        /// Internals
        ///

        fn _get_price_list(self: @ContractState, side: felt252, price: u128) -> OrderList {
            self._price_map.read((side, price))
        }

        fn _set_price_list(ref self: ContractState, side: felt252, price: u128, order_list: OrderList) {
            self._price_map.write((side, price), order_list);
        }

        fn _get_order(self: @ContractState, side: felt252, order_id: u32) -> Order {
            self._order_map.read((side, order_id))
        }

        fn _set_order(ref self: ContractState, side: felt252, order_id: u32, order: Order) {
            self._order_map.write((side, order_id), order);
        }

        fn _set_4_orders(ref self: ContractState, side: felt252, order_ids: Array<u32>, orders: Array<Order>) {
            let mut current_index = 0;
            loop {
                if (current_index == 4) {
                    break true;
                }
                let order_id = *order_ids[current_index];
                let order = *orders[current_index];
                self._order_map.write((side, order_id), order);
                current_index += 1;
            };
        }

        fn _get_num_orders(self: @ContractState, side: felt252) -> u32 {
            self._num_orders.read(side)
        }

        fn _get_volume(self: @ContractState, side: felt252) -> u256 {
            self._volume.read(side)
        }

        fn _create_price(ref self: ContractState, side: felt252, price: u128) {
            self._depth.write(side, self._depth.read(side) + 1);
            let new_order_list = OrderListTrait::new();
            self._price_map.write((side, price), new_order_list);
            let mut rbtree_state = RedBlackTrees::unsafe_new_contract_state();
            RedBlackTrees::InternalImpl::_insert(ref rbtree_state, side, price);
        }

        fn _remove_price(ref self: ContractState, side: felt252, price: u128) {
            self._depth.write(side, self._depth.read(side) - 1);
            let new_order_list = OrderListTrait::new();
            self._price_map.write((side, price), new_order_list);
            let mut rbtree_state = RedBlackTrees::unsafe_new_contract_state();
            RedBlackTrees::InternalImpl::_remove(ref rbtree_state, side, price);
        }

        fn _price_exists(self: @ContractState, side: felt252, price: u128) -> bool {
            let rbtree_state = RedBlackTrees::unsafe_new_contract_state();
            RedBlackTrees::InternalImpl::_exists(@rbtree_state, side, price)
        }

        fn _order_exists(self: @ContractState, side: felt252, order_id: u32) -> bool {
            let order = self._order_map.read((side, order_id));
            if (order.order_id == 0) {
                return false;
            }
            return true;
        }

        fn _get_max_price(self: @ContractState, side: felt252) -> u128 {
            let rbtree_state = RedBlackTrees::unsafe_new_contract_state();
            RedBlackTrees::InternalImpl::_last(@rbtree_state, side)
        }

        fn _get_min_price(self: @ContractState, side: felt252) -> u128 {
            let rbtree_state = RedBlackTrees::unsafe_new_contract_state();
            RedBlackTrees::InternalImpl::_first(@rbtree_state, side)
        }

        fn _get_max_price_list(self: @ContractState, side: felt252) -> OrderList {
            InternalImpl::_get_price_list(self, side, InternalImpl::_get_max_price(self, side))
        }

        fn _get_min_price_list(self: @ContractState, side: felt252) -> OrderList {
            InternalImpl::_get_price_list(self, side, InternalImpl::_get_min_price(self, side))
        }

        fn _remove_order_by_id(ref self: ContractState, side: felt252, order_id: u32) {
            self._num_orders.write(side, self._num_orders.read(side) - 1);
            let order = self._order_map.read((side, order_id));
            self._volume.write(side, self._volume.read(side) - order.quantity);
            let order_list = InternalImpl::_get_price_list(@self, side, order.price);
            let prev_order = InternalImpl::_get_order(@self, side, order.prev_order_id);
            let next_order = InternalImpl::_get_order(@self, side, order.next_order_id);
            let (updated_order_list, updated_order, updated_prev_order, updated_next_order) = order_list.remove_order(@order, @prev_order, @next_order);
            if (updated_order_list.length == 0) {
                InternalImpl::_remove_price(ref self, side, order.price);
            }
            self._price_map.write((side, order.price), updated_order_list);
            self._order_map.write((side, order.order_id), updated_order);
            self._order_map.write((side, prev_order.order_id), updated_prev_order);
            self._order_map.write((side, next_order.order_id), updated_next_order);
        }

        fn _insert_order(ref self: ContractState, side: felt252, quote: Quote) {
            if (InternalImpl::_order_exists(@self, side, quote.order_id)) {
                InternalImpl::_remove_order_by_id(ref self, side, quote.order_id);
            }
            self._num_orders.write(side, self._num_orders.read(side) + 1);
            if (!InternalImpl::_price_exists(@self, side, quote.price)) {
                InternalImpl::_create_price(ref self, side, quote.price);
            }
            let order = OrderTrait::new(quote);
            let order_list = InternalImpl::_get_price_list(@self, side, order.price);
            let tail_order = InternalImpl::_get_order(@self, side, order_list.tail_order_id);
            let (updated_order_list, updated_order, updated_tail_order) = order_list.append_order(@order, @tail_order);

            self._price_map.write((side, order.price), updated_order_list);
            self._order_map.write((side, order.order_id), updated_order);
            self._order_map.write((side, tail_order.order_id), updated_tail_order);
            self._volume.write(side, self._volume.read(side) + order.quantity);
        }

        fn _update_order(ref self: ContractState, side: felt252, order_update: Quote) {
            let order = self._order_map.read((side, order_update.order_id));
            let original_quantity = order.quantity;
            if (order_update.price != order.price) {
                // Change in price, remove order and update tree
                let order_list = InternalImpl::_get_price_list(@self, side, order.price);
                let prev_order = InternalImpl::_get_order(@self, side, order.prev_order_id);
                let next_order = InternalImpl::_get_order(@self, side, order.next_order_id);
                let (updated_order_list, updated_order, updated_prev_order, updated_next_order) = order_list.remove_order(@order, @prev_order, @next_order);
                self._price_map.write((side, order.price), updated_order_list);
                self._order_map.write((side, order.order_id), updated_order);
                self._order_map.write((side, prev_order.order_id), updated_prev_order);
                self._order_map.write((side, next_order.order_id), updated_next_order);
                if (updated_order_list.length == 0) {
                    InternalImpl::_remove_price(ref self, side, order.price);
                }
                InternalImpl::_insert_order(ref self, side, order_update);
            } else {
                // Same price, change in quantity
                let order_list = InternalImpl::_get_price_list(@self, side, order.price);
                let prev_order = InternalImpl::_get_order(@self, side, order.prev_order_id);
                let next_order = InternalImpl::_get_order(@self, side, order.next_order_id);
                let tail_order = InternalImpl::_get_order(@self, side, order_list.tail_order_id);
                let (moved_to_tail, updated_order, updated_order_list, updated_prev_order, updated_next_order, updated_tail_order) = order.update_quantity(order_update.quantity, order_update.block_number, @order_list, @prev_order, @next_order, @tail_order);
                self._price_map.write((side, order.price), updated_order_list);
                self._order_map.write((side, order.order_id), updated_order);
                if (moved_to_tail) {
                    self._order_map.write((side, prev_order.order_id), updated_prev_order);
                    self._order_map.write((side, next_order.order_id), updated_next_order);
                    self._order_map.write((side, tail_order.order_id), updated_tail_order);
                }
            }
            self._volume.write(side, self._volume.read(side) + order_update.quantity - original_quantity);
        }
    }
}