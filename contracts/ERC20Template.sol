// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";


contract ERC20Template is ERC20Burnable {


    constructor(string memory name, string memory symbol) public ERC20(name, symbol) {
      // mints initial supply
       uint256 initialSupply = 1000 *10**18;
      _mint(msg.sender, initialSupply);
    }

   


  
/*    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }*/
}
