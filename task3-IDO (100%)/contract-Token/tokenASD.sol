// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenASD is ERC20 {

    constructor() ERC20("ASD","ASD"){
        _mint(msg.sender,1000000000000000000000000000);
    }
} 
