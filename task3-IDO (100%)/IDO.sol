// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract task3IDO is Ownable {

    address public addressToken;
    address public paymentToken;
    uint256 public totalWhitelist;

    uint256 public startTimeBuy;
    uint256 public endTimeBuy;
    uint256 public startTimeClaim;
    uint256 public endTimeClaim;
    uint256 public amountTobuy;

    uint256 public amoutLimitWhitelist;
    uint256 public amoutLimitFCFS;
    bool public contractPause = true;
    
    address[] temporaryAddress;

    constructor (address _addressToken, address _paymentToken) {
        addressToken = _addressToken;
        paymentToken = _paymentToken;
    }

    //mapping

    mapping(address => bool) public whitelistMap; 
    mapping(address => uint256) public userBoughtMap;

    //event

    event SetNewTimeEvent(
        uint256 startTimeBuy, 
        uint256 endTimeBuy, 
        uint256 startTimeClaim,
        uint256 endTimeClaim
    );

    function setupIDO(address _addressToken, address _paymentToken) public {
        addressToken = _addressToken;
        paymentToken = _paymentToken;
    }

    function setupLimitAmount(uint256 _amoutLimitWhitelist, uint256 _amoutLimitFCFS) public {
        amoutLimitWhitelist = _amoutLimitWhitelist;
        amoutLimitFCFS = _amoutLimitFCFS;
    }

    function setupPauseContract (bool _status) external onlyOwner {
        contractPause = _status;
    }

    function addWhitelist(address[] calldata _newList) external onlyOwner {
        for (uint256 i = 0; i < _newList.length; i++) {
                whitelistMap[_newList[i]] = true;
        }
    }

    function removeWhitelist(address[] calldata _newList) external onlyOwner {
        for (uint256 i = 0; i < _newList.length; i++) {
                whitelistMap[_newList[i]] = false;
        }
    }

    function setTime(uint256 _startTimeBuy, uint256 _endTimeBuy, uint256 _startTimeClaim, uint256 _endTimeClaim) external onlyOwner {
        require(_startTimeBuy < _endTimeBuy, "Invalid time, please check again !");
        require(_startTimeClaim < _endTimeClaim, "Invalid time, please check again !!");
        require(_startTimeClaim >= _endTimeBuy, "Invalid time, please check again !!!"); 

        startTimeBuy = _startTimeBuy;
        endTimeBuy = _endTimeBuy;
        startTimeClaim = _startTimeClaim;
        endTimeClaim = _endTimeClaim;
    }

    function buy(uint256 _amountTobuy) public payable {
        require(contractPause == false, "This contract is Pause");
        require(whitelistMap[msg.sender] == true, "You are not in whitelist !!!");
        require(block.timestamp >= startTimeBuy, "Purchase time will open soon, please wait");
        require(block.timestamp <= endTimeBuy, "Time to buy is over !");

        if (whitelistMap[msg.sender]) {
            require(amountTobuy <= amoutLimitWhitelist, "Over limit amount to buy !");
        } else {
            require(amountTobuy <= amoutLimitFCFS, "Over limit amount to buy !!");
            temporaryAddress.push(msg.sender);
        }

        uint256 price = 100 * _amountTobuy;
        userBoughtMap[msg.sender] += _amountTobuy;

        ERC20(paymentToken).transferFrom(msg.sender, address(this), price);

    } 

    function claim() public {
        require(contractPause == false, "This contract is Pause");
        require(block.timestamp >= startTimeClaim, "Purchase claim will open soon, please wait");
        require(block.timestamp <= endTimeClaim, "Time to claim is over!");

        uint256 amountToClaim = userBoughtMap[msg.sender] *25/100;
        userBoughtMap[msg.sender] -=amountToClaim;        
        require(userBoughtMap[msg.sender] >= 0,"You claim enough"); 

        ERC20(addressToken).transfer(msg.sender, amountToClaim);
    }
}