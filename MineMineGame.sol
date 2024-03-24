// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MineMineGame {
    using SafeMath for uint256;

    IERC1155 public nftBronze = IERC1155(0x2F3337C789C9ca197CA85986cDf461fcf2D0860d);
    IERC1155 public nftSilver = IERC1155(0x90007a5967590BdAB5E2D61B7E87b60b45be0925);
    IERC1155 public nftGold = IERC1155(0xbf757B799e27401a8ead6732739ea471c8a2bFf0);
    IERC20 public token = IERC20(0x0CC05c53C71a1Fc6624290f50f5A1D3C45C57925);

    uint256 public constant STAKE_DURATION = 7 days;
    uint256 public constant REWARD_BRONZE_AMOUNT = 20000;
    uint256 public constant REWARD_SILVER_AMOUNT = 2500;
    uint256 public constant REWARD_GOLD_AMOUNT = 500;
    uint256 public constant BURN_REWARD_AMOUNT = 0.01 ether;

    mapping(address => mapping(uint256 => uint256)) public stakedNFTs;
    mapping(address => mapping(uint256 => uint256)) public stakedTimestamps;

    event NFTStaked(address indexed user, address nftAddress, uint256 tokenId, uint256 timestamp);
    event RewardClaimed(address indexed user, address nftAddress, uint256 tokenId, uint256 rewardAmount);
    event NFTBurned(address indexed user, address nftAddress, uint256 tokenId, uint256 rewardAmount);

    modifier onlyOwner(address nftAddress, uint256 tokenId) {
        require(IERC1155(nftAddress).balanceOf(msg.sender, tokenId) > 0, "You don't own this NFT");
        _;
    }

    function stakeNFT(address nftAddress, uint256 tokenId) external onlyOwner(nftAddress, tokenId) {
        require(
            nftAddress == address(nftBronze) || nftAddress == address(nftSilver) || nftAddress == address(nftGold),
            "Only specific NFTs can be staked"
        );
        require(stakedNFTs[nftAddress][tokenId] == 0, "NFT is already staked");

        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = tokenId;
        amounts[0] = 1;

        IERC1155(nftAddress).safeBatchTransferFrom(msg.sender, address(this), ids, amounts, "");
        stakedNFTs[nftAddress][tokenId] = 1;
        stakedTimestamps[nftAddress][tokenId] = block.timestamp;

        emit NFTStaked(msg.sender, nftAddress, tokenId, block.timestamp);
    }

     function claimReward(address nftAddress, uint256 tokenId) external onlyOwner(nftAddress, tokenId) {
        require(stakedNFTs[nftAddress][tokenId] == 1, "NFT is not staked");
        require(
            block.timestamp >= stakedTimestamps[nftAddress][tokenId].add(STAKE_DURATION),
            "Minimum staking period not reached"
        );

        uint256 rewardAmount;
        if (nftAddress == address(nftBronze)) {
            rewardAmount = REWARD_BRONZE_AMOUNT;
        } else if (nftAddress == address(nftSilver)) {
            rewardAmount = REWARD_SILVER_AMOUNT;
        } else if (nftAddress == address(nftGold)) {
            rewardAmount = REWARD_GOLD_AMOUNT;
        }

        token.transfer(msg.sender, rewardAmount);
        stakedNFTs[nftAddress][tokenId] = 0;
        stakedTimestamps[nftAddress][tokenId] = 0;

        emit RewardClaimed(msg.sender, nftAddress, tokenId, rewardAmount);
    }

    function burnNFT(address nftAddress, uint256 tokenId) external onlyOwner(nftAddress, tokenId) {
        require(
            nftAddress == address(nftBronze) || nftAddress == address(nftSilver) || nftAddress == address(nftGold),
            "Only specific NFTs can be burned"
        );
        require(stakedNFTs[nftAddress][tokenId] == 0, "NFT is staked");

        IERC1155(nftAddress).safeTransferFrom(msg.sender, 0x0000000000000000000000000000000000000000, tokenId, 1, "");
        payable(msg.sender).transfer(BURN_REWARD_AMOUNT);

        emit NFTBurned(msg.sender, nftAddress, tokenId, BURN_REWARD_AMOUNT);
    }
}
