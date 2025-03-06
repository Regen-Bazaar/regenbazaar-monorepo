module regenbazaar::counter {
    use supra_framework::object::{Self, UID};
    use supra_framework::transfer;
    use supra_framework::tx_context::{Self, TxContext};

    /// A counter object that can be incremented
    struct Counter has key, store {
        id: UID,
        value: u64,
    }

    /// Create a new counter with initial value 0
    public fun create(ctx: &mut TxContext): Counter {
        Counter {
            id: object::new(ctx),
            value: 0,
        }
    }

    /// Create and share a Counter object
    public entry fun create_and_share(ctx: &mut TxContext) {
        let counter = create(ctx);
        transfer::share_object(counter);
    }

    /// Increment the counter by 1
    public entry fun increment(counter: &mut Counter) {
        counter.value = counter.value + 1;
    }

    /// Get the current value of the counter
    public fun value(counter: &Counter): u64 {
        counter.value
    }

    /// Increment by a custom amount
    public entry fun increment_by(counter: &mut Counter, amount: u64) {
        counter.value = counter.value + amount;
    }
} 