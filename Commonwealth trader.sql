
WITH
  Cbox_Trade AS (
    SELECT
      NFT."from" AS "Seller",
      NFT."to" AS "Buyer",
      NFT.evt_tx_hash,
      NFT.value AS "Quantity",
      ROUND(
        TRY_CAST(USD.value AS DOUBLE) * 0.000000000000000001,
        6
      ) AS "Amount($)"
    FROM
      erc1155_bnb.evt_transfersingle AS NFT
      JOIN erc20_bnb.evt_transfer AS USD ON NFT.evt_tx_hash = USD.evt_tx_hash
    WHERE
      NFT.contract_address = FROM_HEX('4104af3429548f2a7f8374be0baf0eeb4bc3968b') /* 邦联盒合约 */
  ),
  Four_box_Trade AS (
    SELECT
      NFT."from" AS "Seller",
      NFT."to" AS "Buyer",
      NFT.evt_tx_hash,
      NFT.value AS "Quantity",
      ROUND(
        TRY_CAST(USD.value AS DOUBLE) * 0.000000000000000001,
        6
      ) AS "Amount($)"
    FROM
      erc1155_bnb.evt_transfersingle AS NFT
      JOIN erc20_bnb.evt_transfer AS USD ON NFT.evt_tx_hash = USD.evt_tx_hash
    WHERE
      NFT.contract_address = FROM_HEX('b5740b2ed9d4b63a92dd980f0636922ad77f9f1a') /* 4盒合约 */
  ),
  Cbox_Top_Buyer AS (
    SELECT
      "Buyer",
      ROW_NUMBER() OVER (
        ORDER BY
          SUM("Quantity") DESC
      ) AS "Buyer Rank",
      SUM("Quantity") AS "Quantity",
      SUM("Amount($)") AS "Cost($)"
    FROM
      Cbox_Trade
    GROUP BY
      "Buyer"
    ORDER BY
      "Buyer Rank"
  ),
  Cbox_Top_Seller AS (
    SELECT
      "Seller",
      ROW_NUMBER() OVER (
        ORDER BY
          SUM("Quantity") DESC
      ) AS "Seller Rank",
      --format('%,.0f', TRY_CAST(SUM("Quantity") AS DOUBLE)) AS "Quantity",
      --format('%,.2f', TRY_CAST(SUM("Amount($)") AS DOUBLE)) AS "Profit($)"
      SUM("Quantity")  AS "Quantity",
      SUM("Amount($)") AS "Profit($)"
    FROM
      Cbox_Trade
    GROUP BY
      "Seller"
    ORDER BY
      "Seller Rank"
  ),
  Four_box_Top_Buyer AS (
    SELECT
      "Buyer",
      ROW_NUMBER() OVER (
        ORDER BY
          SUM("Quantity") DESC
      ) AS "Buyer Rank",
      SUM("Quantity")  AS "Quantity",
      SUM("Amount($)") AS "Cost($)"
    FROM
      Four_box_Trade
    GROUP BY
      "Buyer"
    ORDER BY
      "Buyer Rank"
  ),
  Four_box_Top_Seller AS (
    SELECT
      "Seller",
      ROW_NUMBER() OVER (
        ORDER BY
          SUM("Quantity") DESC
      ) AS "Seller Rank",
      SUM("Quantity")  AS "Quantity",
      SUM("Amount($)")  AS "Profit($)"
    FROM
      Four_box_Trade
    GROUP BY
      "Seller"
    ORDER BY
      "Seller Rank"
  ), 
  Union_result AS (
  SELECT
  "Buyer" as "Wallet",
  "Buyer Rank" as "CBox Buyer Rank",
  "Quantity" as "CBox Buy Quantity",
  "Cost($)" as "CBox Buy Cost($)",
  null as "CBox Seller Rank",
  null as "CBox Sell Quantity",
  null as "CBox Sell Profit($)",
  null as "4Box Buyer Rank",
  null as "4Box Buy Quantity",
  null as "4Box Buy Cost($)",
  null as "4Box Seller Rank",
  null as "4Box Sell Quantity",
  null as "4Box Sell Profit($)"
  FROM
  Cbox_Top_Buyer
  union
  SELECT
  "Seller" as "Wallet",
  null as "CBox Buyer Rank",
  null as "CBox Buy Quantity",
  null as "CBox Buy Cost($)",
  "Seller Rank" as "CBox Seller Rank",
  "Quantity" as "CBox Sell Quantity",
  "Profit($)" as "CBox Sell Profit($)",
  null as "4Box Buyer Rank",
  null as "4Box Buy Quantity",
  null as "4Box Buy Profit($)",
  null as "4Box Seller Rank",
  null as "4Box Sell Quantity",
  null as "4Box Sell Profit($)"
  FROM
  Cbox_Top_Seller
  union
  SELECT
  "Buyer" as "Wallet",
  null as "CBox Buyer Rank",
  null as "CBox Buy Quantity",
  null as "CBox Buy Cost($)",
  null as "CBox Seller Rank",
  null as "CBox Sell Quantity",
  null as "CBox Sell Profit($)",
  "Buyer Rank" as "4Box Buyer Rank",
  "Quantity" as "4Box Buy Quantity",
  "Cost($)" as "4Box Buy Cost($)",
  null as "4Box Seller Rank",
  null as "4Box Sell Quantity",
  null as "4Box Sell Profit($)"
  FROM
  Four_box_Top_Buyer
  union
  SELECT
  "Seller" as "Wallet",
  null as "CBox Buyer Rank",
  null as "CBox Buy Quantity",
  null as "CBox Buy Cost($)",
  null as "CBox Seller Rank",
  null as "CBox Sell Quantity",
  null as "CBox Sell Profit($)",
  null as "4Box Buyer Rank",
  null as "4Box Buy Quantity",
  null as "4Box Buy Profit($)",
  "Seller Rank" as "4Box Seller Rank",
  "Quantity" as "4Box Sell Quantity",
  "Profit($)" as "4Box Sell Profit($)"
  FROM
  Four_box_Top_Seller
  )

  select
   "Wallet",
  MIN("CBox Buyer Rank") as "CBox Buyer Rank",
  SUM("CBox Buy Quantity") as "CBox Buy Quantity",
  SUM("CBox Buy Cost($)") as "CBox Buy Cost($)",
  MIN("CBox Seller Rank") as "CBox Seller Rank",
  SUM("CBox Sell Quantity") as "CBox Sell Quantity",
  SUM("CBox Sell Profit($)") as "CBox Sell Profit($)",
  MIN("4Box Buyer Rank") as "4Box Buyer Rank",
  SUM("4Box Buy Quantity") as "4Box Buy Quantity",
  SUM("4Box Buy Cost($)") as "4Box Buy Cost($)",
  MIN("4Box Seller Rank") as "4Box Seller Rank",
  SUM("4Box Sell Quantity") as "4Box Sell Quantity",
  SUM("4Box Sell Profit($)") as "4Box Sell Profit($)"
  FROM "Union_result"
  group by "Wallet"
  order by "CBox Buyer Rank"
 

  
  
  --select *  FROM "Union_result"