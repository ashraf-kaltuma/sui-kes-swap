#[allow(duplicate_alias)]
module sui_swap::kes {
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::option;
    use sui_system::sui_system::{Self, SuiSystemState};
    use sui_system::staking_pool::{StakedSui};

    #[test_only]
    use sui::test_scenario;
    #[test_only]
    use sui::test_utils::assert_eq;

    const FLOAT_SCALING: u64 = 1_000_000_000;
    const EAmountTooLow: u64 = 1;

    public struct KESID has drop {}
    
    public struct Pool has key {
        id: UID,
        kes: Balance<SUI>,
        treasury: TreasuryCap<KESID>,
    }

    #[allow(unused_function)]
    fun initi(witness: KESID, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            9,
            b"KESID",
            b"Dacade Staked KES",
            b"KESID is a Decade Staked KES",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::share_object(Pool {
            id: object::new(ctx),
            kes: balance::zero<SUI>(),
            treasury,  
        });
    }

    entry fun add_liquidity_(pool: &mut Pool, kes: Coin<SUI>, ctx: &mut TxContext) {
        let liquidity = add_liquidity(pool, kes, ctx);
        transfer::public_transfer(liquidity, tx_context::sender(ctx));
    }

    entry fun remove_liquidity_(pool: &mut Pool, kesid: Coin<KESID>, ctx: &mut TxContext) {
        let (kes) = remove_liquidity(pool, kesid, ctx);
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(kes, sender);
    }

    public fun add_liquidity(pool: &mut Pool, kes: Coin<SUI>, ctx: &mut TxContext): Coin<KESID> {
        is_valid_amount(coin::value(&kes));
        let kes_balance = coin::into_balance(kes);
        let kes_added = balance::value(&kes_balance);
        let balance = balance::increase_supply(coin::supply_mut(&mut pool.treasury), kes_added);
        balance::join(&mut pool.kes, kes_balance);
        coin::from_balance(balance, ctx)
    }

    public fun remove_liquidity(pool: &mut Pool, kesid: Coin<KESID>, ctx: &mut TxContext): Coin<SUI> {
        is_valid_amount(coin::value(&kesid));
        let kesid_amount = coin::value(&kesid);
        balance::decrease_supply(coin::supply_mut(&mut pool.treasury), coin::into_balance(kesid));
        coin::take(&mut pool.kes, kesid_amount, ctx)
    }

    public fun stake(kes: Coin<SUI>, state: &mut SuiSystemState, validator_address: address, ctx: &mut TxContext) {
        sui_system::request_add_stake(state, kes, validator_address, ctx);
    }

    public fun unstake(state: &mut SuiSystemState, staked_kes: StakedSui, ctx: &mut TxContext) {
        sui_system::request_withdraw_stake(state, staked_kes, ctx);
    }

    public fun get_supply(pool: &Pool): u64 {
        coin::total_supply(&pool.treasury)
    }

    public fun get_assets(pool: &Pool): u64 {
        balance::value(&pool.kes)
    }

    fun is_valid_amount(amount: u64) {
        assert!(amount >= FLOAT_SCALING, EAmountTooLow)
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        initi(KESID {}, ctx);
    }

    #[test]
    fun test_init_pool_() {
        let owner = @0x01;
        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, owner);
        {
            init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, owner);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let kesid_supply = get_supply(&pool);
            let amt_kes = get_assets(&pool);
            assert_eq(kesid_supply, 0);
            assert_eq(amt_kes, 0);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_add_liquidity_() {
        let owner = @0x01;
        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, owner);
        {
            init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, owner);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;
            let amount = 10 * FLOAT_SCALING;
            let coins = coin::mint_for_testing<SUI>(amount, test_scenario::ctx(scenario));
            let kesid_tokens = add_liquidity(pool_mut, coins, test_scenario::ctx(scenario));
            let kesid_supply = get_supply(&pool);
            let amt_kes = get_assets(&pool);
            assert_eq(kesid_supply, amount);
            assert_eq(amt_kes, amount);
            coin::burn_for_testing(kesid_tokens);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_add_liquidity_multiple_times() {
        let owner = @0x01;
        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, owner);
        {
            init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, owner);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;
            let amount = 10 * FLOAT_SCALING;
            let coins = coin::mint_for_testing<SUI>(amount, test_scenario::ctx(scenario));
            let kesid_tokens = add_liquidity(pool_mut, coins, test_scenario::ctx(scenario));
            let kesid_supply = get_supply(&pool);
            let amt_kes = get_assets(&pool);
            assert_eq(kesid_supply, amount);
            assert_eq(amt_kes, amount);
            coin::burn_for_testing(kesid_tokens);
            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(scenario, owner);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;
            let amount = 10 * FLOAT_SCALING;
            let coins = coin::mint_for_testing<SUI>(amount, test_scenario::ctx(scenario));
            let kesid_tokens = add_liquidity(pool_mut, coins, test_scenario::ctx(scenario));
            let kesid_supply = get_supply(&pool);
            let amt_kes = get_assets(&pool);
            assert_eq(kesid_supply, 2 * amount);
            assert_eq(amt_kes, 2 * amount);
            coin::burn_for_testing(kesid_tokens);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_add_liquidity_multiple_users() {
        let owner = @0x01;
        let user1 = @0x02;
        let user2 = @0x03;
        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, owner);
        {
            init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, owner);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;
            let amount = 10 * FLOAT_SCALING;
            let coins = coin::mint_for_testing<SUI>(amount, test_scenario::ctx(scenario));
            let kesid_tokens = add_liquidity(pool_mut, coins, test_scenario::ctx(scenario));
            let kesid_supply = get_supply(&pool);
            let amt_kes = get_assets(&pool);
            assert_eq(kesid_supply, amount);
            assert_eq(amt_kes, amount);
            coin::burn_for_testing(kesid_tokens);
            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(scenario, user1);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;
            let amount = 10 * FLOAT_SCALING;
            let coins = coin::mint_for_testing<SUI>(amount, test_scenario::ctx(scenario));
            let kesid_tokens = add_liquidity(pool_mut, coins, test_scenario::ctx(scenario));
            let kesid_supply = get_supply(&pool);
            let amt_kes = get_assets(&pool);
            assert_eq(kesid_supply, 2 * amount);
            assert_eq(amt_kes, 2 * amount);
            coin::burn_for_testing(kesid_tokens);
            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(scenario, user2);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;
            let amount = 10 * FLOAT_SCALING;
            let coins = coin::mint_for_testing<SUI>(amount, test_scenario::ctx(scenario));
            let kesid_tokens = add_liquidity(pool_mut, coins, test_scenario::ctx(scenario));
            let kesid_supply = get_supply(&pool);
            let amt_kes = get_assets(&pool);
            assert_eq(kesid_supply, 3 * amount);
            assert_eq(amt_kes, 3 * amount);
            coin::burn_for_testing(kesid_tokens);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_remove_liquidity_() {
        let owner = @0x01;
        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, owner);
        {
            init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, owner);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;
            let amount = 10 * FLOAT_SCALING;
            let coins = coin::mint_for_testing<SUI>(amount, test_scenario::ctx(scenario));
            let kesid_tokens = add_liquidity(pool_mut, coins, test_scenario::ctx(scenario));
            let kesid_supply = get_supply(&pool);
            let amt_kes = get_assets(&pool);
            assert_eq(kesid_supply, amount);
            assert_eq(amt_kes, amount);
            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(scenario, owner);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;
            let kesid_tokens = coin::mint_for_testing<KESID>(10 * FLOAT_SCALING, test_scenario::ctx(scenario));
            let kesid_removed = remove_liquidity(pool_mut, kesid_tokens, test_scenario::ctx(scenario));
            let kesid_supply = get_supply(&pool);
            let amt_kes = get_assets(&pool);
            assert_eq(kesid_supply, 0);
            assert_eq(amt_kes, 0);
            coin::burn_for_testing(kesid_removed);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }
}
