WITH C_box_in AS (
  SELECT
    "to" AS "Wallet",
    SUM(value) AS "Quantity"
  FROM erc1155_bnb.evt_transfersingle
  WHERE
    contract_address = FROM_HEX('4104af3429548f2a7f8374be0baf0eeb4bc3968b') /* 4盒合约 */
  GROUP BY
    "to"
), C_box_out AS (
  SELECT
    "from" AS "Wallet",
    SUM(value) AS "Quantity"
  FROM erc1155_bnb.evt_transfersingle
  WHERE
    contract_address = FROM_HEX('4104af3429548f2a7f8374be0baf0eeb4bc3968b') /* 4盒合约 */
  GROUP BY
    "from"
), C_box_holder AS (
  SELECT
    TRY_CAST(C_box_in."Wallet" AS VARCHAR) AS "Wallet",
    SUM(COALESCE(C_box_in."Quantity", 0)) AS "in_qty",
    SUM(COALESCE(C_box_out."Quantity", 0)) AS "out_qty",
    SUM(COALESCE(C_box_in."Quantity", 0)) - SUM(COALESCE(C_box_out."Quantity", 0)) AS "balance"
  FROM C_box_in
  LEFT OUTER JOIN C_box_out
    ON C_box_out."Wallet" = C_box_in."Wallet"
  GROUP BY
    C_box_in."Wallet"
)
SELECT
  Wallet,
  balance,
  FORMAT('%.3f%%', "balance" * 100.00 / COALESCE((SELECT SUM("balance")FROM C_box_holder),0)) as "4Box %"
FROM (
  SELECT
    Wallet,
    balance,
    ROW_NUMBER() OVER (ORDER BY balance DESC) AS rn
  FROM C_box_holder
) AS ranked
WHERE rn <= 15

UNION ALL
SELECT
  'Others' AS Wallet,
   SUM(balance) AS balance,
   FORMAT('%.3f%%',SUM(balance) * 100.00 / COALESCE((SELECT SUM("balance")FROM C_box_holder),0)) as "4Box %"
  --SUM(balance) / (SELECT SUM(balance) FROM C_box_holder) * 100 AS balance_percentage
FROM C_box_holder
WHERE Wallet NOT IN (
  SELECT Wallet
  FROM (
    SELECT
      Wallet,
      ROW_NUMBER() OVER (ORDER BY balance DESC) AS rn
    FROM C_box_holder
  ) AS ranked
  WHERE rn <= 15
)
ORDER BY balance DESC;