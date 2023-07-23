// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// IERC721.sol
interface IERC721 {
    function transferFrom(address _from, address _to, uint256 _tokenId) external;
    function ownerOf(uint256 _tokenId) external view returns (address);
}

// ERC721.sol (Download from OpenZeppelin GitHub: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol)
// (Omitted here for brevity)

// Auction.sol
contract Auction {
    struct Bid {
        address bidder;
        uint256 amount;
    }

    IERC721 public nft;
    uint256 public tokenId;
    address public owner;
    uint256 public startBlock;
    uint256 public endBlock;
    bool public ended;
    uint256 public highestBid;
    address public highestBidder;
    mapping(address => uint256) public pendingReturns;
    mapping(address => Bid[]) public bids;

    event AuctionStarted(uint256 startBlock, uint256 endBlock);
    event BidPlaced(address indexed bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    constructor(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _startBlock,
        uint256 _endBlock
    ) {
        require(_startBlock < _endBlock, "Invalid block range");
        nft = IERC721(_nftAddress);
        tokenId = _tokenId;
        owner = msg.sender;
        startBlock = _startBlock;
        endBlock = _endBlock;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyAfterStart() {
        require(block.number >= startBlock, "Auction has not started");
        _;
    }

    modifier onlyBeforeEnd() {
        require(!ended, "Auction has ended");
        require(block.number <= endBlock, "Auction has ended");
        _;
    }

    function placeBid() public payable onlyAfterStart onlyBeforeEnd {
        require(msg.value > highestBid, "Bid amount too low");
        
        if (highestBidder != address(0)) {
            // Return the previous highest bid
            pendingReturns[highestBidder] += highestBid;
        }

        highestBid = msg.value;
        highestBidder = msg.sender;

        bids[msg.sender].push(Bid(msg.sender, msg.value));

        emit BidPlaced(msg.sender, msg.value);
    }

    function withdraw() public returns (bool) {
        uint256 amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;
            if (!payable(msg.sender).send(amount)) {
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    function endAuction() public onlyOwner {
        require(!ended, "Auction already ended");
        require(block.number > endBlock, "Auction has not ended yet");

        ended = true;
        
        if (highestBidder != address(0)) {
            nft.transferFrom(address(this), highestBidder, tokenId);
            emit AuctionEnded(highestBidder, highestBid);
        } else {
            nft.transferFrom(address(this), owner, tokenId);
        }
    }
}
