//SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract inso {

    uint256[] public numberArray;
    uint256[] public oddNumberArray;
    uint256[] public sethNumberArray;

    function setArray(uint256 num) public {
        numberArray.push(num);
    }

    function getArray() public view returns(uint256[] memory) {
        return numberArray;
    }
    function oddNumber() public {
        for (uint256 index = 0; index < numberArray.length; index++) {   
            if(numberArray[index] %2 != 0){
                oddNumberArray.push(numberArray[index]);
            }           
        }
    }
    function getoddNumberArray()public view returns(uint256[] memory) {
        return oddNumberArray;
    }

    function sethNumber() public {
        for (uint256 index = 0; index < numberArray.length; index++) {   
            if(numberArray[index] %2 != 0){
                sethNumberArray.push(numberArray[index]);
            }           
        }
    }
    function getsethNumberArray()public view returns(uint256[] memory) {
        return sethNumberArray;
    }
}
