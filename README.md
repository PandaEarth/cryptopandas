# Basics of CryptoPandas:

CryptoPandas is composed of 4 public facing contracts. Below we'll provide an overview on these contracts:

##### PandaCore.sol - ``

Also referred as the main contract, is where Pandas and their ownership are stored.
This also mediates all the main operations, such as breeding, exchange, and part of auctions.

##### SaleClockAuction.sol - ``

Where users are expected to acquire their gen0 kitten. It is also a marketplace where anyone can post their panda for auction.
[See Dutch/Clock auction](https://en.wikipedia.org/wiki/Dutch_auction) - note we also accept an increasing price.
ps: Panda auctions take an initial time and duration, and after duration is over they are not closed. Instead they hold the final price indefinitely


##### SiringClockAuction.sol - ``

A marketplace where any user can offer their Panda as a potential sire for any takers.

##### GeneScience.sol

It's a mystery! Not public for this release.

## Basic Breeding Rules

- 2 Pandas in defferent gender(of course) can breed, except with their siblings or parents.
- They must also be either owned by the same user, or one user offers a Panda siring to another user.
- If you have 2 Panda that fits this condition, you can use one as sire (father) and the other as matron (mother).
- After breeding, the assigned matron will be pregnant and under cooldown, the father will also be under cooldown.
- Cooldown stands for the period of time the panda cannot perform any breeding actions, a Panda's cooldown increases each time it breeds.
- The gensis pandas keep their cooldown time fixed.
- After the matron cooldown is complete, it can give birth, and engage in breeding again right away.
- As pandas breed their cooldowns increase. For the bounty program, the table can be found in `PandaBase.sol`.


## Breeding With Panda You Don't Own

In this case you provide the matron, and have a permissioned sire. There are 2 practical cases this can happen:

1. The owner of a Panda can allow siring to another ethereum address.
2. The owner of another Panda can submit their Panda into a siring clock auction, and the bidder must supply their matron.

## Trading

There are 2 main ways to trade: direct transfer, or auctions:

1. A owner of a panda can put their panda to a clock sales auction.
2. Either transfer to another Ethereum address, or approve to another address.

# Common functions

Here's what we expect to be the most usual flow, and what function are to be called.

1. COO will periodically put a panda to gen0 auction (Main `createGen0Auction()`)
1. user go an buy gen0 panda (Sale Auction `bid()`)
1. user can get panda data (Main `getPanda()`)
1. user can breed their own pandas (Main  `breedWithAuto()`)
1. after cooldown is passed, the COO would have a pregnant panda giving birth (Main `giveBirth()`)
1. user can offer one of their pandas as sire via auction (Main `createSiringAuction()`)
1. user can offer their panda as sire to another user (Main `approveSiring()`)
1. user can bid on an active siring auction (Main `createSiringAuction()`)
1. user can put their panda for sale on auction (Main `createSaleAuction()`)
1. user can buy a panda that is on auction from another user (Sale Auction `bid()`)
1. user can check info of a panda that is to auction (Sale/Siring Auction `getAuction()`)
1. user can cancel an auction they started (Sale/Siring Auction `cancelAuction()`)
1. user can transfer a panda they own to another user (Main `transfer()`)
1. user can allow another user to take ownership of a panda they own (Main `approve()`)
1. once an user has a panda ownership approved, they can claim a panda (Main `transferFrom()`)
1. CEO is the only one that may replace COO or CFO (Main `setCEO()` `setCFO()` `setCOO()`)
1. COO can mint and distribute gensis panda (Main `createWizzPanda()`) before the count reach the total quota.
1. COO can transfer the balance from auctions (Main `withdrawAuctionBalances()`)
1. CFO can drain funds from main contract (Main `withdrawBalance()`)

Please see complete the explanation of roles in `PandaAccessControl.sol`
There are more rules and comments on the source code, please refer to the code and tests in case things don't work as first expected.


