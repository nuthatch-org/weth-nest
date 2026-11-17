# weth-nest

A [nuthatch](https://github.com/nuthatch-org/nuthatch) nest: **WETH on Ethereum mainnet**.

Every wrap, unwrap, transfer and approval of Wrapped Ether (WETH9), decoded into SQL tables on your
own machine, with a view of wraps and unwraps whose sum is the change in supply, and an hourly one.

One binary, one config file, no Postgres, no Docker, no API key.

## What it indexes

**Chain:** `mainnet`. **1 contract**, **4 tables**: `weth__deposit`, `weth__withdrawal`,
`weth__transfer`, `weth__approval`.

| alias | contract | address | from block |
|---|---|---|---|
| `weth` | WETH9 | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | 4,719,568 |

## Verified

Measured on 2026-11-17 with nuthatch 5.22.0 on an 18-core M5 Pro, against the two keyless public
endpoints in `nuthatch.toml`. One run, not a benchmark.

- `nuthatch dev --dir . --backfill 7200 --poll-interval 2s`, the last day of blocks, caught up to the
  tip at block 26,436,828 with **350,823 events in 6 m 34 s** (890 events a second), about 48 a
  block. Both endpoints were answering 429 (101 lines in the log) after an evening of other runs on
  this machine, and nuthatch waited each one out.
- Peak RSS over the run was 263 MB. Disk after it: 15 MB of sealed segments, 33 MB of hot store.
- **Checked against `totalSupply`.** Between blocks 26,429,595 and 26,436,800 the `wraps` view holds
  36,245 wraps and 47,795 unwraps, a net of 9,133.777589649973638446 WETH. `totalSupply()` by
  `eth_call` on dRPC's public endpoint, which this nest does not use, rose by exactly
  9,133.777589649973638446 between blocks 26,429,594 and 26,436,800, to
  2,080,452.007175306762569394.
- Once caught up it read 0 blocks behind the tip at both samples before it was stopped. A restart
  was back at the tip in under a second. The queries below answered in under half a second.

## What it does not do

- **Full history is not attempted here.** About 48 events a block across 21.7 million blocks is a
  job for your own archive node. Pass it with `--rpc` and drop `--backfill`.
- **No balances or supply.** A bounded backfill sees only movements. `wraps` gives the change in
  supply across a range, not the supply itself, and WETH9's `totalSupply` is its ether balance, so
  ether sent to it without `deposit()` would move the supply with no event. Over the range above
  the two agree exactly.
- **Amounts are raw units.** WETH has 18 decimals; divide by 1e18. A division gives a float; keep
  `amount_raw` for sums you will check.

## Run it

```sh
nuthatch init --from https://github.com/nuthatch-org/weth-nest
cd weth-nest
nuthatch dev --dir . --backfill 7200 --poll-interval 2s
```

## Views

- `wraps`: one row per `Deposit` (`kind = 'wrap'`) or `Withdrawal` (`'unwrap'`), with `account` and
  `amount_raw`, negative for an unwrap, so its sum over a range is the change in `totalSupply`.
- `wrap_flow_hourly`: wraps and unwraps per hour and kind, with `net_raw`.

```sql
-- wraps and unwraps over a block range; the net is the change in totalSupply
SELECT kind, count(*) AS events, sum(amount_raw) / 1e18 AS weth
FROM wraps WHERE block_number BETWEEN 26429595 AND 26436800 GROUP BY kind;
```

```
 kind   | events | weth
--------+--------+---------------------
 wrap   | 36245  | 136879.12148903738
 unwrap | 47795  | -127745.34389938739
```

```sql
-- the accounts that unwrapped the most in the window
SELECT account, count(*) AS unwraps, -sum(amount_raw) / 1e18 AS weth
FROM wraps WHERE kind = 'unwrap' GROUP BY account ORDER BY weth DESC LIMIT 5;
```

```
 account                                    | unwraps | weth
--------------------------------------------+---------+-------------------
 0xa0f1c3ad83e07d97b5e7030e177718be175275ea | 221     | 29840.21560785486
 0x9008d19f58aabd9ed0d60971565aa8510560ab41 | 1463    | 17135.85771179215
 0xe08d97e151473a848c3d9ca3f323cb720472d015 | 153     | 9010.309594862416
 0x1111111254eeb25477b68fb85ed929f73a960582 | 8       | 7999.989358873318
 0xd01607c3c5ecaba394d8be377a08590149325722 | 105     | 5697.064956571463
```

```sql
-- hourly flow
SELECT hour, kind, events, net_raw / 1e18 AS weth FROM wrap_flow_hourly ORDER BY hour DESC, kind LIMIT 4;
```

The ABI's parameter names are WETH9's own: `src`, `dst`, `guy` and `wad`.
