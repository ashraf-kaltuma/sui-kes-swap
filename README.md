# `kes_sui_swap` Module

## Overview

The `kes_sui_swap` module is designed for managing liquidity pools that facilitate the swapping of Kenya Shillings (KES) and SUI tokens. This module allows users to create liquidity pools, add and remove liquidity, perform token swaps, and manage daily coupons based on LP (Liquidity Pool) holdings.

## Features

- **Create Liquidity Pool**: Set up a new pool with KES and SUI tokens.
- **Add Liquidity**: Add KES and SUI to an existing pool and receive LP tokens.
- **Remove Liquidity**: Remove liquidity from a pool and redeem KES and SUI tokens based on LP tokens held.
- **Token Swaps**: Swap KES for SUI or SUI for KES within the pool.
- **Daily Coupons**: Issue and manage daily coupons based on the amount of LP tokens held.

## Installation

To use the `kes_sui_swap` module, you need to have the Sui development environment set up. Follow the instructions in the [Sui documentation](https://docs.sui.io/) to install and configure the required tools.

## Usage

### Creating a Liquidity Pool

To create a new liquidity pool, use the `create_swap_pool` function:

```rust
public entry fun create_swap_pool<KES, SUI>(kes: Coin<KES>, sui: Coin<SUI>, clock: &Clock, ctx: &mut TxContext)
```

- **Parameters**:
  - `kes`: Coin object representing the KES tokens.
  - `sui`: Coin object representing the SUI tokens.
  - `clock`: Current clock to generate unique coupon IDs.
  - `ctx`: Transaction context.

### Adding Liquidity

To add liquidity to an existing pool, use the `add_liquidity` function:

```rust
public entry fun add_liquidity<KES, SUI>(pool: &mut Pool<KES, SUI>, kes: Coin<KES>, sui: Coin<SUI>, clock: &Clock, ctx: &mut TxContext)
```

- **Parameters**:
  - `pool`: Reference to the pool where liquidity will be added.
  - `kes`: Coin object representing the KES tokens.
  - `sui`: Coin object representing the SUI tokens.
  - `clock`: Current clock to generate unique coupon IDs.
  - `ctx`: Transaction context.

### Removing Liquidity

To remove liquidity from a pool, use the `remove_liquidity` function:

```rust
public entry fun remove_liquidity<KES, SUI>(pool: &mut Pool<KES, SUI>, lp: Coin<LP<KES, SUI>>, ctx: &mut TxContext)
```

- **Parameters**:
  - `pool`: Reference to the pool from which liquidity will be removed.
  - `lp`: Coin object representing the LP tokens held by the user.
  - `ctx`: Transaction context.

### Swapping Tokens

To swap KES for SUI, use the `swap_kes_to_sui` function:

```rust
public entry fun swap_kes_to_sui<KES, SUI>(pool: &mut Pool<KES, SUI>, kes: Coin<KES>, ctx: &mut TxContext)
```

- **Parameters**:
  - `pool`: Reference to the pool where the swap will occur.
  - `kes`: Coin object representing the KES tokens to be swapped.
  - `ctx`: Transaction context.

To swap SUI for KES, use the `swap_sui_to_kes` function:

```rust
public entry fun swap_sui_to_kes<KES, SUI>(pool: &mut Pool<KES, SUI>, sui: Coin<SUI>, ctx: &mut TxContext)
```

- **Parameters**:
  - `pool`: Reference to the pool where the swap will occur.
  - `sui`: Coin object representing the SUI tokens to be swapped.
  - `ctx`: Transaction context.

### Getting Daily Coupons

To claim a daily coupon based on LP holdings, use the `get_daily_coupon` function:

```rust
public entry fun get_daily_coupon<KES, SUI>(pool: &mut Pool<KES, SUI>, lottery_type: u64, ctx: &mut TxContext)
```

- **Parameters**:
  - `pool`: Reference to the pool associated with the coupon.
  - `lottery_type`: Type of lottery for the coupon.
  - `ctx`: Transaction context.

### Utility Functions

- **Get Swap Factor**:
  
  ```rust
  public entry fun get_swap_factor<KES, SUI>(pool: &Pool<KES, SUI>) : u64
  ```

  Returns the swap factor of KES to SUI in the pool.

- **Get Coupon Details**:
  
  ```rust
  public fun get_coupon_id(coupon: &Coupon) : u64
  public fun get_coupon_lottery_type(coupon: &Coupon) : u64
  public fun get_coupon_lp_amount(coupon: &Coupon) : u64
  public fun get_coupon_epoch(coupon: &Coupon) : u64
  ```

  Retrieve various details of a coupon.

- **Release a Coupon**:
  
  ```rust
  public fun release_coupon(coupon: Coupon)
  ```

  Delete a coupon.

## Error Codes

- **EAmount**: Invalid amount error.
- **ELotteryInvalidTime**: Error for invalid coupon claim time.
- **ELPInvalid**: Error for invalid LP amount.

## Testing

For testing purposes, you can create a coupon with specific details using the `get_coupon_for_testing` function:

```rust
#[test_only]
public fun get_coupon_for_testing(coupon_id: u64, lottery_type: u64, lp_amount: u64, epoch: u64, ctx: &mut TxContext): Coupon
```

- **Parameters**:
  - `coupon_id`: Unique coupon ID.
  - `lottery_type`: Type of lottery.
  - `lp_amount`: Amount of LP tokens.
  - `epoch`: Epoch time.
  - `ctx`: Transaction context.


# sui-kes-swap
