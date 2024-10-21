WITH bid AS (
  SELECT
    "from" AS "Wallet_address",
   -- "evt_tx_hash" AS "Tx_hash",
   -- "evt_block_time" AS "Time",
     SUM("value") AS "Bid_Boxes"    --下注数量
  FROM erc1155_bnb.evt_transfersingle
  WHERE
    "contract_address" = FROM_HEX('4104af3429548f2a7f8374be0baf0eeb4bc3968b') /* 邦联盒合约 */
    AND "operator" = FROM_HEX('013692dc7f3abdf8ce2e992fe6d27e1e82135f80')
    AND "to" = FROM_HEX('000000000000000000000000000000000000dead')
    group by "from"
), win AS (
  SELECT
    "to" AS "Wallet_address",
   -- "evt_tx_hash" AS "Tx_hash",
   -- "evt_block_time" AS "Time",
    SUM("value") AS "Got_4Boxes",      --领取4盒数量
    Count("to") AS "Round"                
  FROM erc1155_bnb.evt_transfersingle
  WHERE
    "contract_address" = FROM_HEX('b5740b2ed9d4b63a92dd980f0636922ad77f9f1a') /* 4盒合约 */
    AND "from" = FROM_HEX('0000000000000000000000000000000000000000')
    group by "to"
), price AS (
SELECT 
  NFT.evt_tx_hash,
  NFT.value,
  NFT.evt_block_time,
  NFT.to as "Buyer",
  round (USD.value * 0.000000000000000001,6) / NFT.value as "Floor_Price"
FROM erc1155_bnb.evt_transfersingle as NFT    --交易盒子数量    
JOIN  erc20_bnb.evt_transfer AS USD on NFT.evt_tx_hash = USD.evt_tx_hash   --本笔交易交易总额
WHERE NFT.contract_address = FROM_HEX('b5740b2ed9d4b63a92dd980f0636922ad77f9f1a')  --4盒合约
order by NFT.evt_block_time desc   --最近一笔交易
limit 1
)

SELECT
  bid."Wallet_address" AS "Wallet_address",
  bid."Bid_Boxes"  AS "Bid_Boxes",
  win."Got_4Boxes" AS "Got_4Boxes",
  win."Got_4Boxes" - bid."Bid_Boxes" as "Winning_4Box",
  (win."Got_4Boxes" - bid."Bid_Boxes") * price."Floor_Price" as "Earned $(Number of Winning 4Box * Floor Price)",
  format('%.2f', TRY_CAST(win."Got_4Boxes" * 100.0 / NULLIF(bid."Bid_Boxes", 0) AS DECIMAL(10, 2))) as "Profit %",
  ROW_NUMBER() OVER (ORDER BY (win."Got_4Boxes" - bid."Bid_Boxes") DESC) AS "Rank",
  win."Round"  AS "Total Played Round"
FROM bid
LEFT JOIN win
  ON bid."Wallet_address" = win."Wallet_address"
  Join price ON 1 = 1
  where win."Got_4Boxes" > bid."Bid_Boxes"
order by "Winning_4Box" DESC