// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract task4INO is Ownable, ReentrancyGuard{
    using SafeMath for uint256;

    address public devWallet; 
    address public paymentToken; 
    address public addressNftClaim;
    address public stakingToken; 
    uint256 public priceNft; 

    uint256 public startTimeClaim;
    uint256 public endTimeClaim;

    uint256 public totalNFTsupply; 

    uint256 public amountStakingFCFS;  
    uint256 public totalLimitFCFS; 
    uint256 public totalLimitMemberShip; 

    constructor(address _devWallet, address _paymentToken, address _stakingToken, uint256 _totalNFTsupply) {

        devWallet = _devWallet;
        paymentToken = _paymentToken;
        stakingToken = _stakingToken;
        totalNFTsupply = _totalNFTsupply;

    }

    struct buyLevelNFT {
        uint256 levelIndex;
        uint256 amountMaxClaimNft;
        address addressNFT; 
    }

    buyLevelNFT[] public listBuyLevelNFT; 

    //mapping

    mapping(address => uint256) public amoutNFTClaimMap; 
    mapping(address => uint256) public userValueNFTIndexMap; 

    mapping(address => bool) public userFCFSMap; 
    mapping(address => bool) public userMembershipMap; 
    mapping(address => bool) public userBuyCompleteMap; 
    mapping(address => bool) public userRegistrationCompleteMap; 
    mapping(address => uint256) public userRegisteredToBuyMap; 

    //setup

    function setupPriceNft (uint256 _priceNft) public onlyOwner { 
        priceNft = _priceNft;
    }

    function setupLevel (uint[] calldata _maxAmoutNFT, address[] calldata  _addressNFT) public onlyOwner {
        delete listBuyLevelNFT; 
        buyLevelNFT memory buyLevelNFT; 

        for(uint256 i=0 ; i <=_maxAmoutNFT.length ; i++){
            
            buyLevelNFT.levelIndex;
            buyLevelNFT.amountMaxClaimNft = _maxAmoutNFT[i];
            buyLevelNFT.addressNFT = _addressNFT[i];

            listBuyLevelNFT.push(buyLevelNFT);
        }

    }

    function setupINO ( uint256 _amountStakingFCFS, uint256 _totalLimitFCFS, uint256 _totalLimitMemberShip, uint256 _priceNft) public {

        require(_totalLimitFCFS + _totalLimitMemberShip == totalNFTsupply, " amount not allowed ! ");

        amountStakingFCFS = _amountStakingFCFS;
        totalLimitFCFS = _totalLimitFCFS;
        priceNft = _priceNft;
        totalLimitMemberShip = _totalLimitMemberShip;
        
    }

    function registerFCFS() public {

        require(userFCFSMap[msg.sender] == false, " You are in FCFS ");
        require(userMembershipMap[msg.sender] == false, " You are in Membership ");
        require(userRegistrationCompleteMap[msg.sender] == false, " You have registration before ");
        require(totalLimitFCFS - 1 >= 0 , " You don't have enough money to buy "); 

        ERC20(stakingToken).transferFrom(msg.sender, address(this), amountStakingFCFS); 
        
        userFCFSMap[msg.sender] = true;
        userRegistrationCompleteMap[msg.sender] = true;

        totalLimitFCFS--;

    }

    function registerMembership(uint256 _levelIndex) public {

        require(userFCFSMap[msg.sender] == false, " You are in FCFS ");
        require(userMembershipMap[msg.sender] == false, " You are in Membership ");
        require(userRegistrationCompleteMap[msg.sender] == false, " You have registration before ");

        buyLevelNFT storage buyLevelNFT = listBuyLevelNFT[_levelIndex];

        uint256 amountNftregisterBuy = buyLevelNFT.amountMaxClaimNft; 

        require(totalLimitMemberShip - amountNftregisterBuy >= 0, " You don't have enough money to buy ");

        address addressNFT = buyLevelNFT.addressNFT;
        uint256 idNFT = ERC721Enumerable(addressNFT).tokenOfOwnerByIndex(msg.sender, 0 );
        ERC721(addressNFT).safeTransferFrom(msg.sender, address(this), idNFT);

        amoutNFTClaimMap[msg.sender] = amountNftregisterBuy;
        userValueNFTIndexMap[msg.sender] = _levelIndex;

        if(_levelIndex == 0 )
        {
            userFCFSMap[msg.sender] = true;
        } else {

            userMembershipMap[msg.sender] = true;
        }
        
        userRegisteredToBuyMap[msg.sender] = buyLevelNFT.amountMaxClaimNft;
        userRegistrationCompleteMap[msg.sender] = true;
        totalLimitMemberShip -= amountNftregisterBuy;
    }

    function setTime (uint256 _startTimeClaim, uint256 _endTimeClaim) public onlyOwner {
        startTimeClaim = _startTimeClaim;
        endTimeClaim = _endTimeClaim;
    }

    //official

    function buyForFCFS() public nonReentrant {

        require(block.timestamp <= endTimeClaim, "It's not time to claim");
        require(userRegistrationCompleteMap[msg.sender] == true, " You must register first ");
        require(userMembershipMap[msg.sender] == false, " You are in Membership ");
        require(userRegistrationCompleteMap[msg.sender] == false, " You have register before ");
        require(userBuyCompleteMap[msg.sender] == false, "you have purchased before !");
        

        ERC20(paymentToken).transferFrom(msg.sender, devWallet, priceNft);

        uint256 idclaimForFCFS = ERC721Enumerable(addressNftClaim).tokenOfOwnerByIndex(address(this), 0);
        ERC721(addressNftClaim).safeTransferFrom(address(this), msg.sender,idclaimForFCFS);

        userBuyCompleteMap[msg.sender] = true;
        
    }

    function buyForMembership(uint256 _amountBuyNFT) public {

        require(block.timestamp <= endTimeClaim, "It's not time to claim");
        require(userRegistrationCompleteMap[msg.sender] == false, " You have registration before ");
        require(_amountBuyNFT <= userRegisteredToBuyMap[msg.sender], " Purchase amount cannot exceed total NFT" );
        require(userFCFSMap[msg.sender] == true, " You are in FcFS ");  

        uint256 totalPriceNft = _amountBuyNFT.mul(priceNft);
        ERC20(paymentToken).transferFrom(msg.sender, devWallet, totalPriceNft);
        for(uint256 i = 0; i <_amountBuyNFT; i++){

            uint256 idNFTOfFCFSofClaim = ERC721Enumerable(addressNftClaim).tokenOfOwnerByIndex(address(this), 0);
            ERC721(addressNftClaim).safeTransferFrom(address(this), msg.sender, idNFTOfFCFSofClaim);
        }
        userRegisteredToBuyMap[msg.sender] -= _amountBuyNFT;
        userBuyCompleteMap[msg.sender] = true;
    }

    function claimNFTForUser() public  {
        buyLevelNFT storage buyLevelNFT = listBuyLevelNFT[userValueNFTIndexMap[msg.sender]];
        address addressNFT = buyLevelNFT.addressNFT;

        uint256 idNFTStake = ERC721Enumerable(addressNFT).tokenOfOwnerByIndex(address(this), 0);
        ERC721(addressNFT).safeTransferFrom(address(this), msg.sender,idNFTStake);

    }

    function claimNFTForOwner() public onlyOwner  {
        uint256 amountClaimNft =  ERC721(addressNftClaim).balanceOf(address(this));
        for(uint256 i = 0; i < amountClaimNft; i++ )
        {
            uint256 idclaimNFTForOwner = ERC721Enumerable(addressNftClaim).tokenOfOwnerByIndex(address(this), 0);
            ERC721(addressNftClaim).safeTransferFrom(address(this), msg.sender,idclaimNFTForOwner);
        }
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

}