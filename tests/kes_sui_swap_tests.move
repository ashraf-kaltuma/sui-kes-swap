#[test_only]
module kes_sui_swap::test_swap {
    use sui::test_scenario::{Self as ts, next_tx};
    use sui::test_utils::{assert_eq};
    use sui::coin::{mint_for_testing};
    use sui::clock::{Clock, Self};
    use sui::random::{Random};

    use std::string::{Self};

    const ADMIN: address = @0x0;    

    use kes_sui_swap::helpers::{init_test_helper};


    const DAY: u64 = (60* 60 * 24 * 1000);

    #[test]
    public fun test_invalid_allocation_time() {
        let mut scenario_test = init_test_helper();
        let scenario = &mut scenario_test;

        // Admin should start a new campaign
        next_tx(scenario, ADMIN);
        {
            

        };
      
        ts::end(scenario_test);
    }

}