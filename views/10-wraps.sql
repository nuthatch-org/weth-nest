-- One row per Deposit (wrap) or Withdrawal (unwrap). amount_raw has 18 decimals and is negative for
-- an unwrap, so sum(amount_raw) over a block range is the change in totalSupply across it.
CREATE VIEW wraps AS
  SELECT block_number, block_timestamp, tx_hash, log_index, 'wrap' AS kind, dst AS account,
         wad_dec AS amount_raw
  FROM weth__deposit
  UNION ALL
  SELECT block_number, block_timestamp, tx_hash, log_index, 'unwrap' AS kind, src AS account,
         -wad_dec AS amount_raw
  FROM weth__withdrawal;
