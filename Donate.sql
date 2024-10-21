WITH inner_query AS (
  SELECT
    "from" AS "Wallet",
    SUM(ROUND(value * 0.000000000000000001, 6)) AS "value"
  FROM erc20_bnb.evt_transfer
  WHERE
    "to" = FROM_HEX('de2f7e4db1588afb9f6aa9247662c4db82d55f2e') /* 捐款钱包 */
    AND contract_address = FROM_HEX('0x55d398326f99059ff775485246999027b3197955') /* USDT */
  GROUP BY
    "from"
), cobx AS (
  SELECT
    SUM(value) AS "Quantity"
  FROM erc1155_bnb.evt_transfersingle
  WHERE
    "to" = FROM_HEX('de2f7e4db1588afb9f6aa9247662c4db82d55f2e') /* 捐款钱包 */
    AND contract_address = FROM_HEX('4104af3429548f2a7f8374be0baf0eeb4bc3968b') /* 邦联盒合约 */
)
SELECT
  "Wallet",
  "value",
  SUM("value") OVER () AS "Total Donate",
  FORMAT(
    '%.3f%%',
    "value" * 100.00 / COALESCE((
      SELECT
        SUM("value")
      FROM inner_query
    ), 0)
  ) AS "Percentage",
cobx."Quantity"   --此钱包中邦联盒数量
FROM inner_query
LEFT JOIN cobx
 ON 1 = 1