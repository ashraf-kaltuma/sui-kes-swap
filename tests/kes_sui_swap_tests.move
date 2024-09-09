#[test_only]
module kes_sui_swap::test_swap {
    use sui::test_scenario::{Self as ts, next_tx};
    use sui::test_utils::{assert_eq};
    use sui::coin::{Self, Coin};
    use sui::clock::{Clock, Self};
    use sui::sui::{SUI};

    use std::debug::{print};

    use kes_sui_swap::helpers::{init_test_helper};
    use kes_sui_swap::kes::{Kes};
    use kes_sui_swap::kes_sui_swap::{Self as kss, Pool, LP};

    const ADMIN: address = @0x0;    

    #[test]
    #[expected_failure(abort_code = kes_sui_swap::kes_sui_swap::ELotteryInvalidTime)]
    public fun test_swap_pool() {
        let mut scenario_test = init_test_helper();
        let scenario = &mut scenario_test;

        next_tx(scenario, ADMIN);
        {
            let sui_coin = coin::mint_for_testing<SUI>(100_000_000_000, ts::ctx(scenario));
            let kes_coin = coin::mint_for_testing<Kes>(100_000_000_000, ts::ctx(scenario));
            let clock = clock::create_for_testing(ts::ctx(scenario));

            kss::create_swap_pool(kes_coin, sui_coin, &clock, ts::ctx(scenario));

            clock.share_for_testing();
        };

        next_tx(scenario, ADMIN);
        {

            let pool = ts::take_shared<Pool<Kes, SUI>>(scenario);

            assert_eq(kss::get_pool_kes(&pool), 100_000_000_000);
            assert_eq(kss::get_pool_sui(&pool), 100_000_000_000);
            assert_eq(kss::get_lp(&pool), 99_999_515_529);
            assert_eq(kss::get_user_table(&pool, ts::ctx(scenario)), true);

            ts::return_shared(pool);
    
        };

        next_tx(scenario, ADMIN);
        {

            let mut pool = ts::take_shared<Pool<Kes, SUI>>(scenario);
            let sui_coin = coin::mint_for_testing<SUI>(100_000_000_000, ts::ctx(scenario));
            let kes_coin = coin::mint_for_testing<Kes>(100_000_000_000, ts::ctx(scenario));
            let clock = ts::take_shared<Clock>(scenario);

            kss::add_liquidity(
                &mut pool,
                kes_coin,
                sui_coin,
                &clock,
                ts::ctx(scenario)
            );

            assert_eq(kss::get_pool_kes(&pool), 200_000_000_000);
            assert_eq(kss::get_pool_sui(&pool), 200_000_000_000);
            assert_eq(kss::get_lp(&pool), 199_999_467_369);
            assert_eq(kss::get_user_table(&pool, ts::ctx(scenario)), true);

            ts::return_shared(pool);
            ts::return_shared(clock);
    
        };

        next_tx(scenario, ADMIN);
        {
            let mut pool = ts::take_shared<Pool<Kes, SUI>>(scenario);
            let lp_token = ts::take_from_sender<Coin<LP<Kes, SUI>>>(scenario);
            // print the lp token value 
            //print(&lp_token);

            kss::remove_liquidity(
                &mut pool,
                lp_token,
                ts::ctx(scenario)
            );

            assert_eq(kss::get_pool_kes(&pool), 200_000_000_000);
            assert_eq(kss::get_pool_sui(&pool), 200_000_000_000);
            assert_eq(kss::get_lp(&pool), 99_999_515_529);
            assert_eq(kss::get_user_table(&pool, ts::ctx(scenario)), true);

            ts::return_shared(pool);
        };

        next_tx(scenario, ADMIN);
        {
            let mut pool = ts::take_shared<Pool<Kes, SUI>>(scenario);
            let kes_coin = coin::mint_for_testing<Kes>(10_000_000_000, ts::ctx(scenario));
            let sui_coin = coin::mint_for_testing<SUI>(10_000_000_000, ts::ctx(scenario));

            kss::swap_kes_to_sui(
                &mut pool,
                kes_coin,
                ts::ctx(scenario)
            );

            kss::swap_sui_to_kes(
                &mut pool,
                sui_coin,
                ts::ctx(scenario)
            );

            assert_eq(kss::get_pool_kes(&pool), 199_524_940_617);
            assert_eq(kss::get_pool_sui(&pool), 200_476_190_476);
            assert_eq(kss::get_lp(&pool), 99_999_515_529);
            assert_eq(kss::get_user_table(&pool, ts::ctx(scenario)), true);

            ts::return_shared(pool);
        };

        next_tx(scenario, ADMIN);
        {
            let mut pool = ts::take_shared<Pool<Kes, SUI>>(scenario);

            kss::get_daily_coupon(
                &mut pool,
                1,
                ts::ctx(scenario)
            );

            assert_eq(kss::get_pool_kes(&pool), 199_524_940_617);
            assert_eq(kss::get_pool_sui(&pool), 200_476_190_476);
            assert_eq(kss::get_lp(&pool), 99_999_515_529);
            assert_eq(kss::get_user_table(&pool, ts::ctx(scenario)), true);

            ts::return_shared(pool);
        };
      
        ts::end(scenario_test);
    }
}
