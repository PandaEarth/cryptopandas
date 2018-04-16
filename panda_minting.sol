pragma solidity ^0.4.11;


import "./panda_auction.sol";

import "./panda_access_control.sol";


/// @title all functions related to creating kittens
contract PandaMinting is PandaAuction {

    // Limits the number of cats the contract owner can ever create.
    //uint256 public constant PROMO_CREATION_LIMIT = 5000;
    uint256 public constant GEN0_CREATION_LIMIT = 45000;


    // Constants for gen0 auctions.
    uint256 public constant GEN0_STARTING_PRICE   = 10 finney;
    uint256 public constant GEN0_AUCTION_DURATION = 1 days;
    uint256 public constant OPEN_PACKAGE_PRICE    = 10 finney;


    // Counts the number of cats the contract owner has created.
    uint256 public promoCreatedCount;


    /// @dev we can create promo kittens, up to a limit. Only callable by COO
    /// @param _genes the encoded genes of the kitten to be created, any value is accepted
    /// @param _owner the future owner of the created kittens. Default to contract COO
    function createWizzPanda(uint256[2] _genes,uint256 _generation, address _owner) external onlyCOO {
        address pandaOwner = _owner;
        if (pandaOwner == address(0)) {
             pandaOwner = cooAddress;
        }

        _createPanda(0, 0, _generation, _genes, pandaOwner);
    }

    /// @dev create pandaWithGenes
    /// @param _genes panda genes
    /// @param _type  0 common 1 rare
    function createPanda(uint256[2] _genes,uint256 _type)
        external
        payable
        onlyCOO
        whenNotPaused
    {
        require(msg.value >= OPEN_PACKAGE_PRICE);
        uint256 kittenId = _createPanda(0, 0, 0, _genes, saleAuction);
        saleAuction.createPanda(kittenId,_type);
    }

    function buyPandaERC20(address _erc20Address,address _buyerAddress,uint256 _pandaID,uint256 _amount)
        external
        onlyCOO
        whenNotPaused
    {
        saleAuctionERC20.bid(_erc20Address,_buyerAddress,_pandaID,_amount);
    }

    /// @dev Creates a new gen0 panda with the given genes and
    ///  creates an auction for it.
    //function createGen0Auction(uint256[2] _genes) external onlyCOO {
    //    require(gen0CreatedCount < GEN0_CREATION_LIMIT);
//
    //    uint256 pandaId = _createPanda(0, 0, 0, _genes, address(this));
    //    _approve(pandaId, saleAuction);
//
    //    saleAuction.createAuction(
    //        pandaId,
    //        _computeNextGen0Price(),
    //        0,
    //        GEN0_AUCTION_DURATION,
    //        address(this)
    //    );
//
    //    gen0CreatedCount++;
    //}

    function createGen0Auction(uint256 _pandaId) external onlyCOO {
        require(_owns(msg.sender, _pandaId));
        //require(pandas[_pandaId].generation==1);

        _approve(_pandaId, saleAuction);

        saleAuction.createGen0Auction(
            _pandaId,
            _computeNextGen0Price(),
            0,
            GEN0_AUCTION_DURATION,
            msg.sender
        );
    }

    /// @dev Computes the next gen0 auction starting price, given
    ///  the average of the past 5 prices + 50%.
    function _computeNextGen0Price() internal view returns (uint256) {
        uint256 avePrice = saleAuction.averageGen0SalePrice();

        // Sanity check to ensure we don't overflow arithmetic
        require(avePrice == uint256(uint128(avePrice)));

        uint256 nextPrice = avePrice + (avePrice / 2);

        // We never auction for less than starting price
        if (nextPrice < GEN0_STARTING_PRICE) {
            nextPrice = GEN0_STARTING_PRICE;
        }

        return nextPrice;
    }
}
