// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenAFC is ERC20 {

    constructor() ERC20("AFC","AFC"){
        _mint(msg.sender,1000000000000000000000000000);
    }
} 
