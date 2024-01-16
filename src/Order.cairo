// Orders represent the core piece of the exchange. Every bid/ask is an Order.
// Orders are doubly linked and have helper functions (next_order, prev_order)
// to help the exchange fullfill orders with quantities larger than a single
// existing Order.

use cairo_clob::data_structures::{Quote, Order, OrderList};
use cairo_clob::OrderList::OrderListTrait;

#[generate_trait]
impl OrderImpl of OrderTrait {
    #[inline(always)]
    fn new(quote: Quote) -> Order {
        new_order(quote)
    }

    fn get_next_order_id(self: @Order) -> u32 {
        *self.next_order_id
    }

    fn get_prev_order_id(self: @Order) -> u32 {
        *self.prev_order_id
    }

    fn update_quantity(self: @Order, new_quantity: u256, new_block_number: u64, order_list: @OrderList, prev_order: @Order, next_order: @Order, tail_order: @Order) -> (bool, Order, OrderList, Order, Order, Order) {
        let mut updated_order_list = *order_list;
        let mut updated_order = *self;
        let mut updated_prev_order = *prev_order;
        let mut updated_next_order = *next_order;
        let mut updated_tail_order = *tail_order;
        let mut moved_to_tail = false;
        if (new_quantity > *self.quantity && *order_list.tail_order_id != *self.order_id) {
            let (updated_order_list, updated_order, updated_prev_order, updated_next_order, updated_tail_order) = order_list.move_to_tail(self, prev_order, next_order, tail_order); // TODO pass correct arguments
            moved_to_tail = true;
        }
        updated_order_list.volume = *order_list.volume - *self.quantity + new_quantity;
        updated_order.quantity = new_quantity;
        updated_order.block_number = new_block_number;
        (moved_to_tail, updated_order, updated_order_list, updated_prev_order, updated_next_order, updated_tail_order)
    }
}

fn new_order(quote: Quote) -> Order {
    Order { order_id: quote.order_id, block_number: quote.block_number, quantity: quote.quantity, price: quote.price, trade_id: quote.trade_id, next_order_id: 0, prev_order_id: 0}
}
