--Google <problem> Trino SQL for general inquiries.
WITH
  time_range as (
    SELECT DISTINCT
      DATE_TRUNC('hour', evt_block_time) AS "hour"
    FROM
      erc1155_bnb.evt_transfersingle
    WHERE
      DATE_TRUNC('hour', evt_block_time) >= TRY_CAST('2024-09-26 15:00' AS TIMESTAMP)
      --and  DATE_TRUNC('hour', evt_block_time) <=   TRY_CAST('2024-11-26 15:00' AS TIMESTAMP)
    ORDER BY
      "hour" DESC
  ),
  claim_list AS (
    SELECT
      "to" as "Wallet",
      DATE_TRUNC('hour', evt_block_time) AS "hour",
      ROW_NUMBER() OVER (
        PARTITION BY
          "to"
        ORDER BY
          evt_block_time
      ) AS rn, --统计领取次数，在计数钱包时，只算第一次的，即rn = 1
      value
    FROM
      erc1155_bnb.evt_transfersingle
    WHERE
      contract_address = FROM_HEX('4104af3429548f2a7f8374be0baf0eeb4bc3968b') /* 邦联盒合约 */
      AND "from" = FROM_HEX('0000000000000000000000000000000000000000')
  ),
  Cbox_burn_per_hour AS (
    SELECT
      time_range.hour AS "hour",
      SUM(COALESCE(NFT.value, 0)) AS "burned Cbox per hour",
      SUM(SUM(COALESCE(NFT.value, 0))) OVER (
        ORDER BY
          time_range.hour
      ) AS "Total burned_Cbox" /* Corrected this line */
    FROM
      time_range
      LEFT JOIN (
        SELECT
          DATE_TRUNC('hour', evt_block_time) AS "hour",
          COALESCE(value, 0) AS "value"
        FROM
          erc1155_bnb.evt_transfersingle
        WHERE
          contract_address = FROM_HEX('4104af3429548f2a7f8374be0baf0eeb4bc3968b') /* 邦联盒合约 */
          AND "to" = FROM_HEX('000000000000000000000000000000000000dead')
      ) AS NFT ON time_range.hour = NFT.hour
    GROUP BY
      time_range.hour
  ),
  com_box AS (
    SELECT
      hour,
      value,
      New_Wallets,
      SUM(New_Wallets) OVER (
        ORDER BY
          hour
      ) AS Total_Wallets,
      SUM(value) OVER (
        ORDER BY
          hour
      ) AS cumulative_value
    FROM
      (
        SELECT
          time_range.hour,
          COUNT(
            CASE
              WHEN claim_list.rn = 1 THEN "Wallet"
            END
          ) AS New_Wallets, --只有第一次领取 rn = 1 计入新钱包
          SUM(COALESCE(claim_list.value, 0)) AS value
        FROM
          time_range
          left join claim_list on time_range.hour = claim_list.hour
          --
        GROUP BY
          time_range.hour
      )
  ),
  four_box_claim AS (
    SELECT
      DATE_TRUNC('hour', evt_block_time) AS hour,
      SUM(value) AS value
    FROM
      erc1155_bnb.evt_transfersingle
    WHERE
      contract_address = FROM_HEX('0xb5740b2ed9d4b63a92dd980f0636922ad77f9f1a') /* 4盒合约 */
      AND "from" = FROM_HEX('0000000000000000000000000000000000000000')
    GROUP BY
      DATE_TRUNC('hour', evt_block_time)
  ),
  four_box AS (
    SELECT
      hour,
      value,
      SUM(value) OVER (
        ORDER BY
          hour
      ) AS cumulative_value
    FROM
      (
        SELECT
          time_range.hour,
          SUM(COALESCE(four_box_claim.value, 0)) AS value
        FROM
          time_range
          left join four_box_claim on time_range.hour = four_box_claim.hour
          --
        GROUP BY
          time_range.hour
      )
  )
SELECT
  time_range.hour AS "Time(UTC)",
  COALESCE(com_box."New_Wallets", 0) as "New Wallets/Hour",
  com_box.Total_Wallets as "Total Wallets",
  com_box.value as "C-Box Claimed/Hour",
  --Cbox_burn_per_hour."Total burned_Cbox",
  --Cbox_burn_per_hour."burned Cbox per hour",
  com_box.cumulative_value - Cbox_burn_per_hour."Total burned_Cbox" AS "Total C-Box",

  four_box.cumulative_value AS "Total 4-Box",
  --  FORMAT('%s%%',TRY_CAST(four_box.cumulative_value * 1.0 / NULLIF(com_box.cumulative_value, 0) AS DECIMAL(10, 2))) AS "4盒转换比",
  -- com_box.cumulative_value / four_box.cumulative_value AS ratio
  --TRY_CAST(TRY_CAST(com_box.cumulative_value * 1.0 / NULLIF(four_box.cumulative_value, 0) AS DECIMAL(10, 2)), VARCHAR(3))
  --format('%.2f', TRY_CAST(com_box.cumulative_value * 1.0 / NULLIF(four_box.cumulative_value, 0) AS DECIMAL(10, 2))) || ' : ' || '1'
  /*CASE
  ---    WHEN com_box.cumulative_value >= four_box.cumulative_value THEN 
  format('%.3f', TRY_CAST(com_box.cumulative_value * 1.00 / NULLIF(four_box.cumulative_value, 0) AS DECIMAL(10, 3))) || ':' || '1'
  WHEN com_box.cumulative_value < four_box.cumulative_value THEN 
  '1' || ':' ||format('%.3f', TRY_CAST(four_box.cumulative_value * 1.00 / NULLIF(com_box.cumulative_value, 0) AS DECIMAL(10, 3)))
  ELSE '-:-'
  END as "C-Box:4-Box Ratio"
   */
  format(
    '%.3f',
    TRY_CAST(
      (com_box.cumulative_value - Cbox_burn_per_hour."Total burned_Cbox") * 1.00 / COALESCE(four_box.cumulative_value, 0) AS DECIMAL (10, 3)
    )
  ) || ':' || '1' as "C-Box:4-Box Ratio"
FROM
  time_range
  LEFT JOIN com_box ON time_range.hour = com_box.hour
  LEFT JOIN four_box ON time_range.hour = four_box.hour
  LEFT JOIN Cbox_burn_per_hour on time_range.hour = Cbox_burn_per_hour.hour
ORDER BY
  "Time(UTC)" DESC