#[test_only]
module kes_sui_swap::helpers {

    use sui::test_scenario::{Self as ts};

    const ADMIN: address = @0x0;

    public fun init_test_helper() : ts::Scenario{
       let mut scenario_val = ts::begin(ADMIN);
       let scenario = &mut scenario_val;
    
       scenario_val
    }
}