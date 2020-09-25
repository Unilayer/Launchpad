// contracts/DexKit.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";

contract UniswapLockedOnMint{

    using SafeERC20 for IERC20;

     // timestamp when token release is enabled
    uint256 private _releaseTime;

    uint256 private _price;

    uint256 private _maxCap;

    uint256 private _mintedBalance;

    address private _owner;

    address private _deployer;

    IERC20 private _token;


    IUniswapV2Router02 private _uniRouter;

    constructor(IUniswapV2Router02 uniRouter, IERC20 token, uint256 releaseTime, address owner, uint256 price) public{
        require(releaseTime > block.timestamp, "UniswapLockedOnMint: release time is before current time");
        _releaseTime = releaseTime;
        _uniRouter = uniRouter;
        _token = token;
        _deployer = _msgSender();
        _price = price;
    }
    /**
    * @dev Add Liquidity to Uniswap at defined price, if no pool exists it will create one. Approve token for router, mint the necessary tokens according 
    *  to available ETH in the contract
    *
     */
    function addLiquidity() public {
        uint256 etherBalance = address(this).balance;
        uint256 tokensToMint = price.mul(etherBalance);
        require(etherBalance > 0, "UniswapLockedOnMint: no ether to add liquidity");
        require(_msgSender() == _token, "UniswapLockedOnMint: Only contract can call this function");
        _token.approve(_uniRouter,-1);
       
        _token.mint(address(this), tokensToMint);
        _mintedBalance = _mintedBalance.plus(tokensToMint);
        
        _uniRouter.addLiquidityETH(_token, tokensToMint , tokensToMint, etherBalance, address(this), block.timestamp + 10000);
    }



   /**
     * @return the time when the tokens are released.
     */
    function releaseTime() public view returns (uint256) {
        return _releaseTime;
    }

      /**
     * @return the owner of the locked funds
     */
    function owner() public view returns (address) {
        return _onwer;
    }
    
    /**
     * @notice Transfers tokens held by Lock to owner.
       @dev Able to withdraw LP funds after release time 
     */
    function release(IERC20 token) public {
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp >= _releaseTime, "UniswapLockedOnMint: current time is before release time");

        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "UniswapLockedOnMint: no tokens to release");

        token.safeTransfer(_owner, amount);
    }

       /**
     * @notice Transfers ETH back to the owner
       @dev Function used only if it was not used all the ETH
     */
    function releaseETH() public {
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp >= _releaseTime, "UniswapLockedOnMint: current time is before release time");
        require(address(this).balance > 0, "UniswapLockedOnMint: no Eth to release");

        owner().send(address(this).balance);
    }
}