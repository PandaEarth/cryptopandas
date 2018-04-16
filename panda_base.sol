pragma solidity ^0.4.11;


import "./panda_access_control.sol";

import "./siring_clock_auction.sol";

import "./gen_science_interface.sol";

import "./sale_clock_auction_erc20.sol";

import "./sale_clock_auction.sol";


/// @title Base contract for CryptoPandas. Holds all common structs, events and base variables.
/// @author Axiom Zen (https://www.axiomzen.co)
/// @dev See the PandaCore contract documentation to understand how the various contract facets are arranged.
contract PandaBase is PandaAccessControl {
    /*** EVENTS ***/

    uint256 public constant GEN0_TOTAL_COUNT = 16200;
    uint256 public gen0CreatedCount;

    /// @dev The Birth event is fired whenever a new kitten comes into existence. This obviously
    ///  includes any time a cat is created through the giveBirth method, but it is also called
    ///  when a new gen0 cat is created.
    event Birth(address owner, uint256 pandaId, uint256 matronId, uint256 sireId, uint256[2] genes);

    /// @dev Transfer event as defined in current draft of ERC721. Emitted every time a kitten
    ///  ownership is assigned, including births.
    event Transfer(address from, address to, uint256 tokenId);

    /*** DATA TYPES ***/

    /// @dev The main Panda struct. Every cat in CryptoPandas is represented by a copy
    ///  of this structure, so great care was taken to ensure that it fits neatly into
    ///  exactly two 256-bit words. Note that the order of the members in this structure
    ///  is important because of the byte-packing rules used by Ethereum.
    ///  Ref: http://solidity.readthedocs.io/en/develop/miscellaneous.html
    struct Panda {
        // The Panda's genetic code is packed into these 256-bits, the format is
        // sooper-sekret! A cat's genes never change.
        uint256[2] genes;

        // The timestamp from the block when this cat came into existence.
        uint64 birthTime;

        // The minimum timestamp after which this cat can engage in breeding
        // activities again. This same timestamp is used for the pregnancy
        // timer (for matrons) as well as the siring cooldown.
        uint64 cooldownEndBlock;

        // The ID of the parents of this panda, set to 0 for gen0 cats.
        // Note that using 32-bit unsigned integers limits us to a "mere"
        // 4 billion cats. This number might seem small until you realize
        // that Ethereum currently has a limit of about 500 million
        // transactions per year! So, this definitely won't be a problem
        // for several years (even as Ethereum learns to scale).
        uint32 matronId;
        uint32 sireId;

        // Set to the ID of the sire cat for matrons that are pregnant,
        // zero otherwise. A non-zero value here is how we know a cat
        // is pregnant. Used to retrieve the genetic material for the new
        // kitten when the birth transpires.
        uint32 siringWithId;

        // Set to the index in the cooldown array (see below) that represents
        // the current cooldown duration for this Panda. This starts at zero
        // for gen0 cats, and is initialized to floor(generation/2) for others.
        // Incremented by one for each successful breeding action, regardless
        // of whether this cat is acting as matron or sire.
        uint16 cooldownIndex;

        // The "generation number" of this cat. Cats minted by the CK contract
        // for sale are called "gen0" and have a generation number of 0. The
        // generation number of all other cats is the larger of the two generation
        // numbers of their parents, plus one.
        // (i.e. max(matron.generation, sire.generation) + 1)
        uint16 generation;
    }

    /*** CONSTANTS ***/

    /// @dev A lookup table indicating the cooldown duration after any successful
    ///  breeding action, called "pregnancy time" for matrons and "siring cooldown"
    ///  for sires. Designed such that the cooldown roughly doubles each time a cat
    ///  is bred, encouraging owners not to just keep breeding the same cat over
    ///  and over again. Caps out at one week (a cat can breed an unbounded number
    ///  of times, and the maximum cooldown is always seven days).
    uint32[9] public cooldowns = [
        uint32(5 minutes),
        uint32(30 minutes),
        uint32(2 hours),
        uint32(4 hours),    
        uint32(8 hours),
        uint32(24 hours),
        uint32(48 hours),
        uint32(72 hours),
        uint32(7 days)
    ];

    // An approximation of currently how many seconds are in between blocks.
    uint256 public secondsPerBlock = 15;

    /*** STORAGE ***/

    /// @dev An array containing the Panda struct for all Pandas in existence. The ID
    ///  of each cat is actually an index into this array. Note that ID 0 is a negacat,
    ///  the unPanda, the mythical beast that is the parent of all gen0 cats. A bizarre
    ///  creature that is both matron and sire... to itself! Has an invalid genetic code.
    ///  In other words, cat ID 0 is invalid... ;-)
    Panda[] pandas;

    /// @dev A mapping from cat IDs to the address that owns them. All cats have
    ///  some valid owner address, even gen0 cats are created with a non-zero owner.
    mapping (uint256 => address) public pandaIndexToOwner;

    // @dev A mapping from owner address to count of tokens that address owns.
    //  Used internally inside balanceOf() to resolve ownership count.
    mapping (address => uint256) ownershipTokenCount;

    /// @dev A mapping from PandaIDs to an address that has been approved to call
    ///  transferFrom(). Each Panda can only have one approved address for transfer
    ///  at any time. A zero value means no approval is outstanding.
    mapping (uint256 => address) public pandaIndexToApproved;

    /// @dev A mapping from PandaIDs to an address that has been approved to use
    ///  this Panda for siring via breedWith(). Each Panda can only have one approved
    ///  address for siring at any time. A zero value means no approval is outstanding.
    mapping (uint256 => address) public sireAllowedToAddress;

    /// @dev The address of the ClockAuction contract that handles sales of Pandas. This
    ///  same contract handles both peer-to-peer sales as well as the gen0 sales which are
    ///  initiated every 15 minutes.
    SaleClockAuction public saleAuction;

    /// @dev The address of a custom ClockAuction subclassed contract that handles siring
    ///  auctions. Needs to be separate from saleAuction because the actions taken on success
    ///  after a sales and siring auction are quite different.
    SiringClockAuction public siringAuction;


    GeneScienceInterface public geneScienceRef;


    SaleClockAuctionERC20 public saleAuctionERC20;


    // wizz panda total
    mapping (uint256 => uint256) public wizzPandaQuota;
    mapping (uint256 => uint256) public wizzPandaCount;

    
    /// wizz panda control
    function getWizzPandaQuotaOf(uint256 _tp) view external returns(uint256) {
        return wizzPandaQuota[_tp];
    }

    function getWizzPandaCountOf(uint256 _tp) view external returns(uint256) {
        return wizzPandaCount[_tp];
    }

    function setTotalWizzPandaOf(uint256 _tp,uint256 _total) external onlyCLevel {
        require (wizzPandaQuota[_tp]==0);
        require (_total==uint256(uint32(_total)));
        wizzPandaQuota[_tp] = _total;
    }

    function getWizzTypeOf(uint256 _id) view external returns(uint256) {
        Panda memory _p = pandas[_id];
        return geneScienceRef.getWizzType(_p.genes);
    }

    /// @dev Assigns ownership of a specific Panda to an address.
    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        // Since the number of kittens is capped to 2^32 we can't overflow this
        ownershipTokenCount[_to]++;
        // transfer ownership
        pandaIndexToOwner[_tokenId] = _to;
        // When creating new kittens _from is 0x0, but we can't account that address.
        if (_from != address(0)) {
            ownershipTokenCount[_from]--;
            // once the kitten is transferred also clear sire allowances
            delete sireAllowedToAddress[_tokenId];
            // clear any previously approved ownership exchange
            delete pandaIndexToApproved[_tokenId];
        }
        // Emit the transfer event.
        Transfer(_from, _to, _tokenId);
    }

    /// @dev An internal method that creates a new panda and stores it. This
    ///  method doesn't do any checking and should only be called when the
    ///  input data is known to be valid. Will generate both a Birth event
    ///  and a Transfer event.
    /// @param _matronId The panda ID of the matron of this cat (zero for gen0)
    /// @param _sireId The panda ID of the sire of this cat (zero for gen0)
    /// @param _generation The generation number of this cat, must be computed by caller.
    /// @param _genes The panda's genetic code.
    /// @param _owner The inital owner of this cat, must be non-zero (except for the unPanda, ID 0)
    function _createPanda(
        uint256 _matronId,
        uint256 _sireId,
        uint256 _generation,
        uint256[2] _genes,
        address _owner
    )
        internal
        returns (uint)
    {
        // These requires are not strictly necessary, our calling code should make
        // sure that these conditions are never broken. However! _createPanda() is already
        // an expensive call (for storage), and it doesn't hurt to be especially careful
        // to ensure our data structures are always valid.
        require(_matronId == uint256(uint32(_matronId)));
        require(_sireId == uint256(uint32(_sireId)));
        require(_generation == uint256(uint16(_generation)));


        // New panda starts with the same cooldown as parent gen/2
        uint16 cooldownIndex = 0;
        // when contract creation, geneScienceRef is null 
        if (pandas.length>0){
            uint16 pureDegree = uint16(geneScienceRef.getPureFromGene(_genes));
            if (pureDegree==0) {
                pureDegree = 1;
            }
            cooldownIndex = 1000/pureDegree;
            if (cooldownIndex%10 < 5){
                cooldownIndex = cooldownIndex/10;
            }else{
                cooldownIndex = cooldownIndex/10 + 1;
            }
            cooldownIndex = cooldownIndex - 1;
            if (cooldownIndex > 8) {
                cooldownIndex = 8;
            }
            uint256 _tp = geneScienceRef.getWizzType(_genes);
            if (_tp>0 && wizzPandaQuota[_tp]<=wizzPandaCount[_tp]) {
                _genes = geneScienceRef.clearWizzType(_genes);
                _tp = 0;
            }
            // gensis panda cooldownIndex should be 24 hours
            if (_tp == 1){
                cooldownIndex = 5;
            }

            // increase wizz counter
            if (_tp>0){
                wizzPandaCount[_tp] = wizzPandaCount[_tp] + 1;
            }
            // all gen0&gen1 except gensis
            if (_generation <= 1 && _tp != 1){
                require(gen0CreatedCount<GEN0_TOTAL_COUNT);
                gen0CreatedCount++;
            }
        }

        Panda memory _panda = Panda({
            genes: _genes,
            birthTime: uint64(now),
            cooldownEndBlock: 0,
            matronId: uint32(_matronId),
            sireId: uint32(_sireId),
            siringWithId: 0,
            cooldownIndex: cooldownIndex,
            generation: uint16(_generation)
        });
        uint256 newKittenId = pandas.push(_panda) - 1;

        // It's probably never going to happen, 4 billion cats is A LOT, but
        // let's just be 100% sure we never let this happen.
        require(newKittenId == uint256(uint32(newKittenId)));

        // emit the birth event
        Birth(
            _owner,
            newKittenId,
            uint256(_panda.matronId),
            uint256(_panda.sireId),
            _panda.genes
        );

        // This will assign ownership, and also emit the Transfer event as
        // per ERC721 draft
        _transfer(0, _owner, newKittenId);
        
        return newKittenId;
    }

    // Any C-level can fix how many seconds per blocks are currently observed.
    function setSecondsPerBlock(uint256 secs) external onlyCLevel {
        require(secs < cooldowns[0]);
        secondsPerBlock = secs;
    }
}
