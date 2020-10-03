// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import "./Launchpad.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract UniswapLocked{

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

     // timestamp when token release is enabled
    uint256 private _releaseTime;

    uint256 private _priceInv;

    uint256 private _maxCap;

    uint256 private _mintedBalance;

    address private _owner;

    address private _deployer;

    uint256 constant private MAX_INT = 2**256 - 1;

    uint256 constant private BASE_PRICE = 100000;

    IERC20 private _token;


    IUniswapV2Router02 private _uniRouter;

    constructor(IUniswapV2Router02 uniRouter, uint256 releaseTime, address owner, uint256 priceInv) public{
        require(releaseTime > block.timestamp, "UniswapLockedOnMint: release time is before current time");
        _releaseTime = releaseTime;
        _uniRouter = uniRouter;
        _deployer = msg.sender;
        _priceInv = priceInv;
        _owner = owner;
    }

    function setupToken(IERC20 token) public {
        require(msg.sender == _deployer, "Only deployer can set Token");
        _token = token;
    }

    receive() external payable {

    }
    /**
    * @dev Add Liquidity to Uniswap at defined price, if no pool exists it will create one. Approve token for router, mint the necessary tokens according 
    *  to available ETH in the contract
    *
     */
    function addLiquidityOnMint() public {
        uint256 etherBalance = address(this).balance;
        uint256 tokensToMint = _priceInv.div(BASE_PRICE).mul(etherBalance);
        require(address(_token) != address(0), "UniswapLockedOnMint: Token can not be zero");
        require(etherBalance > 0, "UniswapLockedOnMint: no ether to add liquidity");
        require(msg.sender == address(_deployer), "UniswapLockedOnMint: Only deployer can call this function");
       
        _token.approve(address(_uniRouter), MAX_INT);
       
        _token.mint(address(this), tokensToMint);
        _mintedBalance = _mintedBalance.add(tokensToMint);
        
        _uniRouter.addLiquidityETH(address(_token), tokensToMint , tokensToMint, etherBalance, address(this), block.timestamp + 10000);
    }
    /**
    * @dev Add Liquidity to Uniswap at defined price, if no pool exists it will create one.
    *  Approve token for router, require contract to have the necessary tokens
    *
     */
    function addLiquidity() public {
        require(address(_token) != address(0), "UniswapLockedOnMint: Token can not be zero");
        uint256 etherBalance = address(this).balance;
        uint256 tokensToMint = _priceInv.div(BASE_PRICE).mul(etherBalance);
        require(etherBalance > 0, "UniswapLockedOnMint: no ether to add liquidity");
        require( _token.balanceOf(address(this)) > 0, "UniswapLockedOnMint: no ether to add liquidity");
        require(msg.sender == address(_deployer), "UniswapLocked: Only deployer can call this function");
        _token.approve(address(_uniRouter), MAX_INT);
  
        _uniRouter.addLiquidityETH(address(_token), tokensToMint , tokensToMint, etherBalance, address(this), block.timestamp + 10000);
    }

    /**
    * @dev Add Liquidity to Uniswap using current balance , if no pool exists it will create one.
    *  Approve token for router, require contract to have the necessary tokens
    *
     */
    function addLiquidityByBalance() public {
        require(address(_token) != address(0), "UniswapLockedOnMint: Token can not be zero");
        uint256 etherBalance = address(this).balance;
        uint256 tokensAmount = _priceInv.div(BASE_PRICE).mul(etherBalance);
        require(etherBalance > 0, "UniswapLockedOnMint: no ether to add liquidity");
        require( _token.balanceOf(address(this)) >= tokensAmount, "UniswapLockedOnMint: no ether to add liquidity");
        require(msg.sender == address(_deployer), "UniswapLocked: Only deployer can call this function");
        _token.approve(address(_uniRouter), MAX_INT);
  
        _uniRouter.addLiquidityETH(address(_token), tokensAmount , tokensAmount, etherBalance, address(this), block.timestamp + 10000);
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
        return _owner;
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

        payable(owner()).transfer(address(this).balance);
    }
}