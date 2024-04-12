// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MetaSkeletorLotteryTicket is ERC721, Ownable {
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public constant MAX_MINT_PER_WALLET = 5;
    uint256 public constant MINT_COST = 0.05 ether;
    uint256 public currentTokenId;
    uint256 public totalSupplyCount;
    bool public lotteryClosed;
    address[] public participants;
    address public winner;
    uint256 public winnerPrize;
    uint256 public totalPrizePool;
    mapping(uint256 => bool) private tokenExists;

    event TicketMinted(address indexed minter, uint256 indexed tokenId);
    event WinnerSelected(address indexed winner, uint256 indexed winningTokenId);

    constructor() ERC721("MetaSkeletor Lottery Ticket", "MSLT") Ownable(msg.sender) {}

    // Function to mint lottery tickets
    function mintTicket() public payable {
        require(msg.value == MINT_COST, "Incorrect minting cost");        
        require(!_isLotteryClosed(), "Lottery is closed");
        require(_getMintedCountPerWallet(msg.sender) < MAX_MINT_PER_WALLET, "Maximum mint per wallet reached");

        uint256 newTokenId = currentTokenId + 1;
        _safeMint(msg.sender, newTokenId);
        currentTokenId = newTokenId;
        tokenExists[newTokenId] = true;

        emit TicketMinted(msg.sender, newTokenId);

        if (totalSupplyCount == MAX_SUPPLY) {
            _selectWinner();
        }
        totalSupplyCount++;
    }

    // Function to check if lottery is closed
    function _isLotteryClosed() internal view returns (bool) {
        return lotteryClosed;
    }

    // Function to get the count of minted tokens per wallet
    function _getMintedCountPerWallet(address _wallet) internal view returns (uint256) {
        uint256 count;
        for (uint256 i = 0; i < totalSupplyCount; i++) {
            if (ownerOf(i) == _wallet) {
                count++;
            }
        }
        return count;
    }

    // Function to select a winner when all tickets are minted
    function _selectWinner() internal {
        require(!_isLotteryClosed(), "Lottery is already closed");        
        require(totalSupplyCount == MAX_SUPPLY, "All tickets are not minted yet");

        uint256 winningTokenId = uint256(keccak256(abi.encodePacked(block.timestamp, block.basefee, block.number))) % MAX_SUPPLY + 1;
        winner = ownerOf(winningTokenId);
        lotteryClosed = true;

        winnerPrize = (totalPrizePool * 80) / 100; // 80% of total prize pool for winner
        payable(winner).transfer(winnerPrize); // Transfer prize to the winner

        emit WinnerSelected(winner, winningTokenId);
        
    }

    // Function to withdraw any remaining NFTs back to the owner
    function withdrawRemainingNFTs() public onlyOwner {
        require(_isLotteryClosed(), "Lottery is still open");
        for (uint256 i = totalSupplyCount + 1; i <= MAX_SUPPLY; i++) {
            if (!tokenExists[i]) {
                _safeMint(owner(), i);
                tokenExists[i] = true;
            }
        }
    }

    // Function to withdraw any remaining ether from the contract
    function withdrawEther() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Override _beforeTokenTransfer to include lottery participants
    function _beforeTokenTransfer(address from, address to, uint256 ) internal {     
        if (from == address(0)) {
            participants.push(to);
            totalPrizePool += MINT_COST; // Add minting cost to total prize pool
        }
    }

    // Function to get lottery participants    
    function getParticipants() public view returns (address[] memory) {
        return participants;
    }
}