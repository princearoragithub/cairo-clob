//  A red-black tree used to store prices

#[starknet::contract]
mod RedBlackTrees {
    use cairo_clob::data_structures::RBTNode;

    const EMPTY: u128 = 0;

    //
    // Storage Pair
    //
    #[storage]
    struct Storage {
        _root: LegacyMap::<felt252, u128>, // @dev Root of the RBTree for each side
        _nodes: LegacyMap::<(felt252, u128), RBTNode>, // @dev price nodes for each bid/ask trees
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        ///
        /// Internals
        ///

        fn _first(self: @ContractState, side: felt252) -> u128 {
            let mut key = self._root.read(side);
            if (key != EMPTY) {
                loop {
                    if (self._nodes.read((side, key)).left == EMPTY) {
                        break true;
                    }
                    key = self._nodes.read((side, key)).left;
                };
            }
            key
        }

        fn _last(self: @ContractState, side: felt252) -> u128 {
            let mut key = self._root.read(side);
            if (key != EMPTY) {
                loop {
                    if (self._nodes.read((side, key)).right == EMPTY) {
                        break true;
                    }
                    key = self._nodes.read((side, key)).right;
                };
            }
            key
        }

        fn _exists(self: @ContractState, side: felt252, key: u128) -> bool {
            (key != EMPTY) && ((key == self._root.read(side) || (self._nodes.read((side, key)).parent != EMPTY)))
        }

        fn _rotate_left(ref self: ContractState, side: felt252, key: u128) {
            let mut key_node = self._nodes.read((side, key));
            let cursor = key_node.right;
            let key_parent = key_node.parent;
            let mut cursor_node = self._nodes.read((side, cursor));
            let cursor_left = cursor_node.left;
            key_node.right = cursor_left;
            if (cursor_left != EMPTY) {
                let mut cursor_left_node = self._nodes.read((side, cursor_left));
                cursor_left_node.parent = key;
                self._nodes.write((side, cursor_left), cursor_left_node);
            }
            cursor_node.parent = key_parent;
            if (key_parent == EMPTY) {
                self._root.write(side, cursor);
            } else {
                let mut key_parent_node = self._nodes.read((side, key_parent));
                if (key == key_parent_node.left) {
                    key_parent_node.left = cursor;
                } else {
                    key_parent_node.right = cursor;
                }
                self._nodes.write((side, key_parent), key_parent_node);
            }
            cursor_node.left = key;
            key_node.parent = cursor;
            self._nodes.write((side, cursor), cursor_node);
            self._nodes.write((side, key), key_node);
        }

        fn _rotate_right(ref self: ContractState, side: felt252, key: u128) {
            let mut key_node = self._nodes.read((side, key));
            let cursor = key_node.left;
            let key_parent = key_node.parent;
            let mut cursor_node = self._nodes.read((side, cursor));
            let cursor_right = cursor_node.right;
            key_node.left = cursor_right;
            if (cursor_right != EMPTY) {
                let mut cursor_right_node = self._nodes.read((side, cursor_right));
                cursor_right_node.parent = key;
                self._nodes.write((side, cursor_right), cursor_right_node);
            }
            cursor_node.parent = key_parent;
            if (key_parent == EMPTY) {
                self._root.write(side, cursor);
            } else {
                let mut key_parent_node = self._nodes.read((side, key_parent));
                if (key == key_parent_node.right) {
                    key_parent_node.right = cursor;
                } else {
                    key_parent_node.left = cursor;
                }
                self._nodes.write((side, key_parent), key_parent_node);
            }
            cursor_node.right = key;
            key_node.parent = cursor;
            self._nodes.write((side, cursor), cursor_node);
            self._nodes.write((side, key), key_node);
        }

        fn _replace_parent(ref self: ContractState, side: felt252, a: u128, b: u128) {
            let mut a_node = self._nodes.read((side, a));
            let mut b_node = self._nodes.read((side, b));
            let b_parent = b_node.parent;
            a_node.parent = b_parent;
            if (b_parent == EMPTY) {
                self._root.write(side, a);
            } else {
                let mut b_parent_node = self._nodes.read((side, b_parent));
                if (b == b_parent_node.left) {
                    b_parent_node.left = a;
                } else {
                    b_parent_node.right = a;
                }
                self._nodes.write((side, b_parent), b_parent_node);
            }
            self._nodes.write((side, a), a_node);
        }

        fn _insert_fixup(ref self: ContractState, side: felt252, mut key: u128) {
            loop {
                let mut key_node = self._nodes.read((side, key));
                let mut key_parent = key_node.parent;
                let mut key_parent_node = self._nodes.read((side, key_parent));

                if (key == self._root.read(side) || !key_parent_node.red) {
                    break true;
                }

                let mut key_parent_parent = key_parent_node.parent;
                let mut key_parent_parent_node = self._nodes.read((side, key_parent_parent));

                if (key_parent == key_parent_parent_node.left) {
                    let cursor = key_parent_parent_node.right;
                    let mut cursor_node = self._nodes.read((side, cursor));
                    if (cursor_node.red) {
                        key_parent_node.red = false;
                        cursor_node.red = false;
                        key_parent_parent_node.red = true;
                        self._nodes.write((side, key_parent), key_parent_node);
                        self._nodes.write((side, cursor), cursor_node);
                        self._nodes.write((side, key_parent_parent), key_parent_parent_node);
                        key = key_parent_parent;
                    } else {
                        if (key == key_parent_node.right) {
                            key = key_parent;
                            InternalImpl::_rotate_left(ref self, side, key);
                        }
                        key_node = self._nodes.read((side, key));
                        key_parent = key_node.parent;
                        key_parent_node = self._nodes.read((side, key_parent));
                        key_parent_parent = key_parent_node.parent;
                        key_parent_parent_node = self._nodes.read((side, key_parent_parent));
                        key_parent_node.red = false;
                        key_parent_parent_node.red = true;
                        self._nodes.write((side, key_parent), key_parent_node);
                        self._nodes.write((side, key_parent_parent), key_parent_parent_node);
                        InternalImpl::_rotate_right(ref self, side, key_parent_parent);
                    }
                } else {
                    let cursor = key_parent_parent_node.left;
                    let mut cursor_node = self._nodes.read((side, cursor));
                    if (cursor_node.red) {
                        key_parent_node.red = false;
                        cursor_node.red = false;
                        key_parent_parent_node.red = true;
                        self._nodes.write((side, key_parent), key_parent_node);
                        self._nodes.write((side, cursor), cursor_node);
                        self._nodes.write((side, key_parent_parent), key_parent_parent_node);
                        key = key_parent_parent;
                    } else {
                        if (key == key_parent_node.left) {
                            key = key_parent;
                            InternalImpl::_rotate_right(ref self, side, key);
                        }
                        key_node = self._nodes.read((side, key));
                        key_parent = key_node.parent;
                        key_parent_node = self._nodes.read((side, key_parent));
                        key_parent_parent = key_parent_node.parent;
                        key_parent_parent_node = self._nodes.read((side, key_parent_parent));
                        key_parent_node.red = false;
                        key_parent_parent_node.red = true;
                        self._nodes.write((side, key_parent), key_parent_node);
                        self._nodes.write((side, key_parent_parent), key_parent_parent_node);
                        InternalImpl::_rotate_left(ref self, side, key_parent_parent);
                    }
                }
                EMPTY;
            };
            let mut root_node = self._nodes.read((side, self._root.read(side)));
            root_node.red = false;
            self._nodes.write((side, self._root.read(side)), root_node);
        }

        fn _insert(ref self: ContractState, side: felt252, mut key: u128) {
            assert(key != EMPTY, 'empty key');
            assert(!InternalImpl::_exists(@self, side, key), 'key exists');

            let mut cursor = EMPTY;
            let mut probe = self._root.read(side);

            loop {
                if (probe == EMPTY) {
                    break true;
                }
                cursor = probe;
                let probe_node = self._nodes.read((side, probe));
                if (key < probe) {
                    probe = probe_node.left;
                } else {
                    probe = probe_node.right;
                }
                EMPTY;
            };
            self._nodes.write((side, key), RBTNode {parent: cursor, left: EMPTY, right: EMPTY, red: true});
            if (cursor == EMPTY) {
                self._root.write(side, key);
            } else {
                let mut cursor_node = self._nodes.read((side, cursor));
                if (key < cursor) {
                    cursor_node.left = key;
                } else {
                    cursor_node.right = key;
                }
                self._nodes.write((side, cursor), cursor_node);
            }
            InternalImpl::_insert_fixup(ref self, side, key);
        }

        fn _remove_fixup(ref self: ContractState, side: felt252, mut key: u128) {
            loop {
                let mut key_node = self._nodes.read((side, key));
                let mut key_parent = key_node.parent;
                let mut key_parent_node = self._nodes.read((side, key_parent));

                if (key == self._root.read(side) || key_node.red) {
                    break true;
                }

                if (key == key_parent_node.left) {
                    let mut cursor = key_parent_node.right;
                    let mut cursor_node = self._nodes.read((side, cursor));
                    if (cursor_node.red) {
                        cursor_node.red = false;
                        key_parent_node.red = true;
                        self._nodes.write((side, key_parent), key_parent_node);
                        self._nodes.write((side, cursor), cursor_node);
                        InternalImpl::_rotate_left(ref self, side, key_parent);
                        key_parent_node = self._nodes.read((side, key_parent));
                        cursor = key_parent_node.right;
                    }
                    cursor_node = self._nodes.read((side, cursor));
                    let mut cursor_left = cursor_node.left;
                    let mut cursor_right = cursor_node.right;
                    let mut cursor_left_node = self._nodes.read((side, cursor_left));
                    let mut cursor_right_node = self._nodes.read((side, cursor_right));
                    if (!cursor_left_node.red && !cursor_right_node.red) {
                        cursor_node.red = true;
                        self._nodes.write((side, cursor), cursor_node);
                        key = key_parent;
                    } else {
                        if (!cursor_right_node.red) {
                            cursor_left_node.red = false;
                            cursor_node.red = true;
                            self._nodes.write((side, cursor), cursor_node);
                            self._nodes.write((side, cursor_left), cursor_left_node);
                            InternalImpl::_rotate_right(ref self, side, cursor);
                            key_parent_node = self._nodes.read((side, key_parent));
                            cursor = key_parent_node.right;
                            cursor_node = self._nodes.read((side, cursor));
                        }
                        cursor_node.red = key_parent_node.red;
                        key_parent_node.red = false;
                        cursor_right = cursor_node.right;
                        cursor_right_node = self._nodes.read((side, cursor_right));
                        cursor_right_node.red = false;
                        self._nodes.write((side, cursor), cursor_node);
                        self._nodes.write((side, cursor_right), cursor_right_node);
                        self._nodes.write((side, key_parent), key_parent_node);
                        InternalImpl::_rotate_left(ref self, side, key_parent);
                        key  = self._root.read(side);
                    }
                } else {
                    let mut cursor = key_parent_node.left;
                    let mut cursor_node = self._nodes.read((side, cursor));
                    if (cursor_node.red) {
                        cursor_node.red = false;
                        key_parent_node.red = true;
                        self._nodes.write((side, key_parent), key_parent_node);
                        self._nodes.write((side, cursor), cursor_node);
                        InternalImpl::_rotate_right(ref self, side, key_parent);
                        key_parent_node = self._nodes.read((side, key_parent));
                        cursor = key_parent_node.left;
                    }
                    cursor_node = self._nodes.read((side, cursor));
                    let mut cursor_left = cursor_node.left;
                    let mut cursor_right = cursor_node.right;
                    let mut cursor_left_node = self._nodes.read((side, cursor_left));
                    let mut cursor_right_node = self._nodes.read((side, cursor_right));
                    if (!cursor_left_node.red && !cursor_right_node.red) {
                        cursor_node.red = true;
                        self._nodes.write((side, cursor), cursor_node);
                        key = key_parent;
                    } else {
                        if (!cursor_left_node.red) {
                            cursor_right_node.red = false;
                            cursor_node.red = true;
                            self._nodes.write((side, cursor), cursor_node);
                            self._nodes.write((side, cursor_right), cursor_right_node);
                            InternalImpl::_rotate_left(ref self, side, cursor);
                            key_parent_node = self._nodes.read((side, key_parent));
                            cursor = key_parent_node.left;
                            cursor_node = self._nodes.read((side, cursor));
                        }
                        cursor_node.red = key_parent_node.red;
                        key_parent_node.red = false;
                        cursor_left = cursor_node.left;
                        cursor_left_node = self._nodes.read((side, cursor_left));
                        cursor_left_node.red = false;
                        self._nodes.write((side, cursor), cursor_node);
                        self._nodes.write((side, cursor_left), cursor_left_node);
                        self._nodes.write((side, key_parent), key_parent_node);
                        InternalImpl::_rotate_right(ref self, side, key_parent);
                        key  = self._root.read(side);
                    }
                }
                EMPTY;
            };
            let mut root_node = self._nodes.read((side, self._root.read(side)));
            root_node.red = false;
            self._nodes.write((side, self._root.read(side)), root_node);
        }

        fn _remove(ref self: ContractState, side: felt252, mut key: u128) {
            assert(key != EMPTY, 'empty key');
            assert(InternalImpl::_exists(@self, side, key), 'no key');

            let mut cursor = EMPTY;
            let mut probe = EMPTY;

            let key_node = self._nodes.read((side, key));

            if (key_node.left == EMPTY || key_node.right == EMPTY) {
                cursor = key;
            } else {
                cursor = key_node.right;
                loop {
                    let mut cursor_node = self._nodes.read((side, cursor));
                    if (cursor_node.left == EMPTY) {
                        break true;
                    }
                    cursor = cursor_node.left;
                };
            }

            let mut cursor_node = self._nodes.read((side, cursor));

            if (cursor_node.left != EMPTY) {
                probe = cursor_node.left;
            } else {
                probe = cursor_node.right;
            }

            let mut probe_node = self._nodes.read((side, probe));

            let cursor_parent = cursor_node.parent;
            probe_node.parent = cursor_parent;
            self._nodes.write((side, probe), probe_node);

            if (cursor_parent != EMPTY) {
                let mut cursor_parent_node = self._nodes.read((side, cursor_parent));
                if (cursor == cursor_parent_node.left) {
                    cursor_parent_node.left = probe;
                } else {
                    cursor_parent_node.right = probe;
                }
                self._nodes.write((side, cursor_parent), cursor_parent_node);
            } else {
                self._root.write(side, probe);
            }

            let fixup_required = !cursor_node.red;

            if (cursor != key) {
                InternalImpl::_replace_parent(ref self, side, cursor, key);
                cursor_node = self._nodes.read((side, cursor));
                let key_node = self._nodes.read((side, key));
                cursor_node.left = key_node.left;
                let cursor_left = cursor_node.left;
                let mut cursor_left_node = self._nodes.read((side, cursor_left));
                cursor_left_node.parent = cursor;
                cursor_node.right = key_node.right;
                let cursor_right = cursor_node.right;
                let mut cursor_right_node = self._nodes.read((side, cursor_right));
                cursor_right_node.parent = cursor;
                cursor_node.red = key_node.red;
                self._nodes.write((side, cursor), cursor_node);
                self._nodes.write((side, cursor_left), cursor_left_node);
                self._nodes.write((side, cursor_right), cursor_right_node);
                cursor = key;
            }

            if (fixup_required) {
                InternalImpl::_remove_fixup(ref self, side, key);
            }

            self._nodes.write((side, cursor), RBTNode {parent: EMPTY, left: EMPTY, right: EMPTY, red: true});
        }
    }
}