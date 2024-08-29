/// Module: kes_sui_swap
/// This module provides functionalities for swapping between Kenya Shillings (KES) and SUI tokens.
/// It includes creating liquidity pools, adding/removing liquidity, swapping tokens, and managing daily coupons.
#[allow(deprecated_usage)]
module kes_sui_swap::kes_sui_swap {
    use sui::tx_context::{sender, epoch};
    use sui::math;
    use sui::balance::{Self, Balance, Supply};
    use sui::coin::{Self, Coin};
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};

    // Error codes
    const EAmount: u64 = 1; // Error code for invalid amount
    const ELotteryInvalidTime: u64 = 2; // Error code for invalid lottery time
    const ELPInvalid: u64 = 3; // Error code for invalid LP amount
    const EInvalidPool: u64 = 4; // Error code for invalid pool

    // Liquidity Pool Token (LP) type to represent the liquidity pool
    public struct LP<phantom KES, phantom SUI> has drop {}

    // Data structure for storing coupon information
    public struct CouponData has store, drop {
        coupon_id: u64, // Unique identifier for the coupon
        lp_amount: u64, // Amount of LP tokens held
        last_update_epoch: u64, // Last epoch when the coupon was updated
    }
    
    // Liquidity pool data structure
    public struct Pool<phantom KES, phantom SUI> has key {
        id: UID, // Unique identifier for the pool
        kes_bal: Balance<KES>, // Balance of KES in the pool
        sui_bal: Balance<SUI>, // Balance of SUI in the pool
        lp_supply: Supply<LP<KES, SUI>>, // Supply of LP tokens for the pool
        coupon_table: Table<address, CouponData>, // Table to store coupon data for users
        is_active: bool, // Status of the pool (active or inactive)
    }

    // Coupon data structure
    public struct Coupon has key {
        id: UID, // Unique identifier for the coupon
        coupon_id: u64, // Unique coupon ID
        lottery_type: u64, // Type of lottery
        lp_amount: u64, // Amount of LP tokens the coupon represents
        epoch: u64, // Epoch when the coupon was created
    }

    // Create a new liquidity pool with KES and SUI
    public entry fun create_swap_pool<KES, SUI>(
        kes: Coin<KES>, 
        sui: Coin<SUI>, 
        clock: &Clock, 
        ctx: &mut TxContext
    ) {
        let kes_amount = coin::value(&kes);
        let sui_amount = coin::value(&sui);

        // Ensure that the amounts of KES and SUI are positive
        assert!(kes_amount > 0 && sui_amount > 0, EAmount);

        // Convert coins into balances
        let kes_balance = coin::into_balance(kes);
        let sui_balance = coin::into_balance(sui);

        // Calculate initial LP tokens based on the square root of the product of KES and SUI amounts
        let lp_amount = math::sqrt(kes_amount) * math::sqrt(sui_amount);
        let mut lp_supply = balance::create_supply(LP<KES, SUI> {});
        let lp_balance = balance::increase_supply(&mut lp_supply, lp_amount);

        // Create a new liquidity pool
        let mut pool = Pool {
            id: object::new(ctx), // Create a new unique object ID for the pool
            kes_bal: kes_balance,
            sui_bal: sui_balance,
            lp_supply,
            coupon_table: table::new<address, CouponData>(ctx), // Create a new table for storing coupon data
            is_active: true, // Set the pool as active
        };
        
        // Record coupon data in the coupon table
        let coupon_data = CouponData {
            coupon_id: clock::timestamp_ms(clock), // Generate a unique coupon ID using the current timestamp
            lp_amount: lp_amount,
            last_update_epoch: epoch(ctx),
        };
        pool.coupon_table.add(sender(ctx), coupon_data); // Add coupon data to the table

        transfer::share_object(pool); // Share the pool object
        transfer::public_transfer(coin::from_balance(lp_balance, ctx), sender(ctx)); // Transfer LP tokens to the sender
    }

    // Add liquidity to an existing pool
    public entry fun add_liquidity<KES, SUI>(
        pool: &mut Pool<KES, SUI>, 
        kes: Coin<KES>, 
        sui: Coin<SUI>,
        clock: &Clock, 
        ctx: &mut TxContext
    ) {
        assert!(pool.is_active, EInvalidPool); // Ensure the pool is active

        let kes_amount = coin::value(&kes);
        let sui_amount = coin::value(&sui);

        // Ensure that the amounts of KES and SUI are positive
        assert!(kes_amount > 0 && sui_amount > 0, EAmount);

        let kes_amount_in_pool = balance::value(&pool.kes_bal);
        let sui_amount_in_pool = balance::value(&pool.sui_bal);

        // Add KES and SUI to the pool
        balance::join(&mut pool.kes_bal, coin::into_balance(kes));
        balance::join(&mut pool.sui_bal, coin::into_balance(sui));

        // Calculate the ratio of the new amounts to the existing pool amounts
        let factor_a = kes_amount_in_pool / kes_amount;
        let factor_b = sui_amount_in_pool / sui_amount;
        let add_kes_amount: u64;
        let add_sui_amount: u64;

        // Adjust the ratio if needed and refund excess to user
        if (factor_a == factor_b) {
            add_kes_amount = kes_amount;
            add_sui_amount = sui_amount;
        } else if (factor_a < factor_b) { // Too much KES provided, refund excess
            add_kes_amount = kes_amount_in_pool / factor_b;
            add_sui_amount = sui_amount;
            let refund_kes_amount = kes_amount - add_kes_amount;
            let refund_kes_balance = balance::split(&mut pool.kes_bal, refund_kes_amount);
            transfer::public_transfer(coin::from_balance(refund_kes_balance, ctx), sender(ctx));
        } else { // Too much SUI provided, refund excess
            add_kes_amount = kes_amount;
            add_sui_amount = sui_amount_in_pool / factor_a;
            let refund_sui_amount = sui_amount - add_sui_amount;
            let refund_sui_balance = balance::split(&mut pool.sui_bal, refund_sui_amount);
            transfer::public_transfer(coin::from_balance(refund_sui_balance, ctx), sender(ctx));
        };

        // Calculate new LP amount
        let lp_amount_in_pool = balance::supply_value(&pool.lp_supply);
        let new_lp_amount = math::sqrt(kes_amount_in_pool + add_kes_amount) * math::sqrt(sui_amount_in_pool + add_sui_amount);
        let add_lp_amount = new_lp_amount - lp_amount_in_pool;

        // Increase LP supply and return voucher to user
        let lp_balance = balance::increase_supply(&mut pool.lp_supply, add_lp_amount);
        let lp_coin = coin::from_balance(lp_balance, ctx);
        transfer::public_transfer(lp_coin, sender(ctx));

        // Update coupon data in the coupon table
        let cur_epoch = epoch(ctx);
        if (table::contains(&pool.coupon_table, sender(ctx))) {
            let coupon_data = table::borrow_mut(&mut pool.coupon_table, sender(ctx));
            coupon_data.lp_amount = coupon_data.lp_amount + add_lp_amount;
            coupon_data.last_update_epoch = cur_epoch;
        } else {
            let coupon_data = CouponData {
                coupon_id: clock::timestamp_ms(clock),
                lp_amount: add_lp_amount,
                last_update_epoch: cur_epoch,
            };
            pool.coupon_table.add(sender(ctx), coupon_data);
        };
    }

    // Remove liquidity from a pool
    public entry fun remove_liquidity<KES, SUI>(
        pool: &mut Pool<KES, SUI>, 
        lp: Coin<LP<KES, SUI>>, 
        ctx: &mut TxContext
    ) {
        assert!(pool.is_active, EInvalidPool); // Ensure the pool is active

        let lp_amount = coin::value(&lp);

        // Ensure that the LP amount is positive
        assert!(lp_amount > 0, ELPInvalid);

        let kes_amount_in_pool = balance::value(&pool.kes_bal);
        let sui_amount_in_pool = balance::value(&pool.sui_bal);
        let lp_amount_in_pool = balance::supply_value(&pool.lp_supply);

        // Calculate the amount of KES and SUI to remove based on the LP amount
        let factor = lp_amount / lp_amount_in_pool;
        let remove_kes_amount = factor * kes_amount_in_pool;
        let remove_sui_amount = factor * sui_amount_in_pool;

        // Withdraw KES and SUI from the pool
        let kes_balance = balance::split(&mut pool.kes_bal, remove_kes_amount);
        let sui_balance = balance::split(&mut pool.sui_bal, remove_sui_amount);

        // Decrease LP supply and return KES and SUI to user
        balance::decrease_supply(&mut pool.lp_supply, coin::into_balance(lp));
        transfer::public_transfer(coin::from_balance(kes_balance, ctx), sender(ctx));
        transfer::public_transfer(coin::from_balance(sui_balance, ctx), sender(ctx));

        // Update or remove coupon data from the table if LP amount is zero
        assert!(table::contains(&pool.coupon_table, sender(ctx)), ELPInvalid);
        let coupon_data = table::borrow_mut(&mut pool.coupon_table, sender(ctx));
        coupon_data.lp_amount = coupon_data.lp_amount - lp_amount;
        if (coupon_data.lp_amount == 0) {
            table::remove(&mut pool.coupon_table, sender(ctx));
        };
    }

    // Swap KES for SUI in the pool
    public entry fun swap_kes_to_sui<KES, SUI>(
        pool: &mut Pool<KES, SUI>, 
        kes: Coin<KES>, 
        ctx: &mut TxContext
    ) {
        assert!(pool.is_active, EInvalidPool); // Ensure the pool is active

        let swap_kes_amount = coin::value(&kes) as u128;
        let kes_amount_in_pool = balance::value(&pool.kes_bal) as u128;
        let sui_amount_in_pool = balance::value(&pool.sui_bal) as u128;

        // Ensure that the KES amount is positive
        assert!(swap_kes_amount > 0, EAmount);

        // Calculate the new amount of SUI in the pool after the swap
        let new_sui_amount = kes_amount_in_pool * sui_amount_in_pool / (kes_amount_in_pool + swap_kes_amount);
        let swap_sui_amount = (sui_amount_in_pool - new_sui_amount) as u64;
        balance::join(&mut pool.kes_bal, coin::into_balance(kes));
        let sui_balance = balance::split(&mut pool.sui_bal, swap_sui_amount);
        transfer::public_transfer(coin::from_balance(sui_balance, ctx), sender(ctx));
    }

    // Swap SUI for KES in the pool
    public entry fun swap_sui_to_kes<KES, SUI>(
        pool: &mut Pool<KES, SUI>, 
        sui: Coin<SUI>, 
        ctx: &mut TxContext
    ) {
        assert!(pool.is_active, EInvalidPool); // Ensure the pool is active

        let swap_sui_amount = coin::value(&sui) as u128;
        let kes_amount_in_pool = balance::value(&pool.kes_bal) as u128;
        let sui_amount_in_pool = balance::value(&pool.sui_bal) as u128;

        // Ensure that the SUI amount is positive
        assert!(swap_sui_amount > 0, EAmount);

        // Calculate the new amount of KES in the pool after the swap
        let new_kes_amount = sui_amount_in_pool * kes_amount_in_pool / (sui_amount_in_pool + swap_sui_amount);
        let swap_kes_amount = (kes_amount_in_pool - new_kes_amount) as u64;
        balance::join(&mut pool.sui_bal, coin::into_balance(sui));
        let kes_balance = balance::split(&mut pool.kes_bal, swap_kes_amount);
        transfer::public_transfer(coin::from_balance(kes_balance, ctx), sender(ctx));
    }

    // Get a daily coupon based on the user's LP amount
    public entry fun get_daily_coupon<KES, SUI>(
        pool: &mut Pool<KES, SUI>, 
        lottery_type: u64, 
        ctx: &mut TxContext
    ) {
        // Check if the user has coupon data
        assert!(table::contains(&pool.coupon_table, sender(ctx)), EAmount);
        let coupon_data = table::borrow_mut(&mut pool.coupon_table, sender(ctx));

        let lp_amount = coupon_data.lp_amount;
        assert!(lp_amount > 0, EAmount);

        let lp_amount_in_pool = balance::supply_value(&pool.lp_supply);
        assert!(lp_amount_in_pool > 0, EAmount);

        // Ensure that the user holds a significant amount of LP tokens to participate
        let lp_factor = lp_amount_in_pool / lp_amount;
        assert!(lp_factor < 100000, EAmount); // Must hold at least 1/10000th of total LP to participate

        let cur_epoch = epoch(ctx);
        assert!(coupon_data.last_update_epoch < cur_epoch, ELotteryInvalidTime); // Check if the user can claim a new coupon

        // Update the coupon data and issue a new coupon
        coupon_data.last_update_epoch = cur_epoch;

        let coupon = Coupon {
            id: object::new(ctx),
            coupon_id: coupon_data.coupon_id,
            lottery_type,
            lp_amount,
            epoch: cur_epoch,
        };

        transfer::transfer(coupon, sender(ctx)); // Transfer the coupon to the user
    }

    // Calculate the swap factor of KES to SUI
    public entry fun get_swap_factor<KES, SUI>(
        pool: &Pool<KES, SUI>
    ): u64 {
        assert!(pool.is_active, EInvalidPool); // Ensure the pool is active

        let kes_amount_in_pool = balance::value(&pool.kes_bal);
        let sui_amount_in_pool = balance::value(&pool.sui_bal);
        10000 * kes_amount_in_pool / sui_amount_in_pool // Return the ratio scaled by 10000
    }

    // Getters for Coupon fields
    public fun get_coupon_id(coupon: &Coupon): u64 {
        coupon.coupon_id
    }

    public fun get_coupon_lottery_type(coupon: &Coupon): u64 {
        coupon.lottery_type
    }

    public fun get_coupon_lp_amount(coupon: &Coupon): u64 {
        coupon.lp_amount
    }

    public fun get_coupon_epoch(coupon: &Coupon): u64 {
        coupon.epoch
    }

    // Release a coupon, effectively deleting it
    public fun release_coupon(coupon: Coupon) {
        let Coupon { id, coupon_id: _coupon_id, lottery_type: _lottery_type, lp_amount: _lp_amount, epoch: _epoch } = coupon;
        id.delete(); // Delete the coupon object
    }

    // For testing: Create a coupon with specific details
    #[test_only]
    public fun get_coupon_for_testing(
        coupon_id: u64, 
        lottery_type: u64, 
        lp_amount: u64, 
        epoch: u64, 
        ctx: &mut TxContext
    ): Coupon {
        Coupon {
            id: object::new(ctx),
            coupon_id,
            lottery_type,
            lp_amount,
            epoch
        }
    }

    // New Feature: Deactivate a pool (only for admin)
    public entry fun deactivate_pool<KES, SUI>(
        pool: &mut Pool<KES, SUI>, 
        ctx: &mut TxContext
    ) {
        assert!(sender(ctx) == pool.id.into(), EInvalidPool); // Ensure the sender is the pool admin
        pool.is_active = false; // Deactivate the pool
    }

    // New Feature: Reactivate a pool (only for admin)
    public entry fun reactivate_pool<KES, SUI>(
        pool: &mut Pool<KES, SUI>, 
        ctx: &mut TxContext
    ) {
        assert!(sender(ctx) == pool.id.into(), EInvalidPool); // Ensure the sender is the pool admin
        pool.is_active = true; // Reactivate the pool
    }
}
