// A doubly linked list of Orders. Used to iterate through Orders when
// a price match is found. Each OrderList is associated with a single
// price. Since a single price match can have more quantity than a single
// Order, we may need multiple Orders to fullfill a transaction. The
// OrderList makes this easy to do. OrderList is naturally arranged by time.
// Orders at the front of the list have priority.

use cairo_clob::data_structures::{Order, OrderList};
use cairo_clob::Order::OrderTrait;

#[generate_trait]
impl OrderListImpl of OrderListTrait {
    #[inline(always)]
    fn new() -> OrderList {
        OrderList { head_order_id: 0, tail_order_id: 0 , length: 0, volume: 0, last_order_id: 0 }
    }

    fn get_head_order_id(self: @OrderList) -> u32 {
        *self.head_order_id
    }

    fn get_volume(self: @OrderList) -> u256 {
        *self.volume
    }

    fn append_order(self: @OrderList, order: @Order, tail_order: @Order) -> (OrderList, Order, Order) {
        let mut updated_order_list = *self;
        let mut updated_order = *order;
        let mut updated_tail_order = *tail_order;
        if (*self.length == 0) {
            updated_order.next_order_id = 0;
            updated_order.prev_order_id = 0;
            updated_order_list.head_order_id = *order.order_id;
            updated_order_list.tail_order_id = *order.order_id;
        } else {
            updated_order.next_order_id = 0;
            updated_order.prev_order_id = *tail_order.order_id;
            updated_order_list.tail_order_id = *order.order_id;
            updated_tail_order.next_order_id = *order.order_id;
        }
        updated_order_list.length += 1;
        updated_order_list.volume += *order.quantity;

        (updated_order_list, updated_order, updated_tail_order)
    }

    fn remove_order(self: @OrderList, order: @Order, prev_order: @Order, next_order: @Order) -> (OrderList, Order, Order, Order) {
        let mut updated_order_list = *self;
        let mut updated_order = *order;
        let mut updated_prev_order = *prev_order;
        let mut updated_next_order = *next_order;

        updated_order_list.volume -= updated_order.quantity;
        updated_order_list.length -= 1;

        if (updated_order_list.length == 0) {
            // no more orders, return
            updated_order.order_id = 0;
            return (updated_order_list, updated_order, updated_prev_order, updated_next_order);
        }

        let next_order_id = *order.next_order_id;
        let prev_order_id = *order.prev_order_id;
        // more orders, relink
        if (next_order_id != 0 && prev_order_id != 0) {
            updated_next_order.prev_order_id = prev_order_id;
            updated_prev_order.next_order_id = next_order_id;
        } else if (next_order_id != 0) {
            updated_next_order.prev_order_id = 0;
            updated_order_list.head_order_id = next_order_id;
        } else if (prev_order_id != 0) {
            updated_prev_order.next_order_id = 0;
            updated_order_list.tail_order_id = prev_order_id;
        }

        updated_order.order_id = 0;
        
        (updated_order_list, updated_order, updated_prev_order, updated_next_order)
    }

    fn move_to_tail(self: @OrderList, order: @Order, prev_order: @Order, next_order: @Order, tail_order: @Order) -> (OrderList, Order, Order, Order, Order) {
        // After updating the quantity of an existing Order, move it to the tail of the OrderList
        // Check to see that the quantity is larger than existing, update the quantities, then move to tail.
        
        let mut updated_order_list = *self;
        let mut updated_order = *order;
        let mut updated_prev_order = *prev_order;
        let mut updated_next_order = *next_order;
        let mut updated_tail_order = *tail_order;

        if (*order.prev_order_id != 0) { // This Order is not the first Order in the OrderList
            updated_prev_order.next_order_id = *order.next_order_id;
        } else {    // This Order is the first Order in the OrderList
            updated_order_list.head_order_id = *order.next_order_id;
        }

        updated_next_order.prev_order_id = *order.prev_order_id;

        updated_order.prev_order_id = updated_order_list.tail_order_id;
        updated_order.next_order_id = 0;

        updated_tail_order.next_order_id = updated_order.order_id;
        updated_order_list.tail_order_id = updated_order.order_id;

        (updated_order_list, updated_order, updated_prev_order, updated_next_order, updated_tail_order)
    }
}
