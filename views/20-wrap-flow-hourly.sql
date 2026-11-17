-- Wraps and unwraps per hour and the net change in supply. net_raw has 18 decimals.
CREATE VIEW wrap_flow_hourly AS
  SELECT block_timestamp - (block_timestamp % 3600) AS hour,
         kind,
         count(*) AS events,
         sum(amount_raw) AS net_raw
  FROM wraps
  GROUP BY block_timestamp - (block_timestamp % 3600), kind;
