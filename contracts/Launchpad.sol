// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import "./UniswapLocked.sol";

contract Launchpad{

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
   
      /**
     * @dev  emitted when sold out
     *
     */
    event SoldOut();
    //  This value needs to be the same on UniswapLocked Contract
    uint256 private constant _BASE_PRICE = 100000;

    uint256 private constant _totalPercent = 10000;
    // Layer charges 2.5 % and TrustSwap another 2.5%
    uint256 private constant _launchpadFeePercent = 250;

    address private constant _layerFeeAddress = 0x0fF6ffcFDa92c53F615a4A75D982f399C989366b;

    address private constant _trustSwapFeeAddress = 0x0fF6ffcFDa92c53F615a4A75D982f399C989366b;

    mapping (address => uint256) private _balancesToClaim;

    uint256 private _liquidityLock;

    uint256 private _mintedLiquidity;

    uint256 private _liquidityPercent;

    uint256 private _teamPercent;

    uint256 private _end;

    uint256 private _start;

    uint256 private _releaseTime;
    // We use price inverted for better calculations
    uint256 private _priceInv;

     // We use price inverted for better calculations
    uint256 private _priceUniInv;

    bool    private _isRefunded = false;

    bool    private _isSoldOut = false;

    bool    private _isLiquiditySetup = false;

    uint256 private _raisedETH;

    uint256 private _claimedAmount;

    uint256 private _softCap;

    uint256 private _maxCap;

    address private _teamWallet;

    address private _owner;

    IERC20 private _token;

    UniswapLocked private _uniLocked;

    constructor(IUniswapV2Router02 uniRouter, IERC20 token, uint256 priceUniInv, uint256 priceInv, address owner, address teamWallet, uint256 softCap, uint256 maxCap, uint256 liquidityPercent, uint256 teamPercent, uint256 end, uint256 start, uint256 releaseTime) 
    public 
    {
        require(start > block.timestamp, "start time needs to be above current time");
        require(releaseTime > block.timestamp, "release time above current time");
        require(end > start, "End time above start time");
        require(liquidityPercent < 3000, "Max Liquidity allowed is 30 %");
        require(priceInv > _BASE_PRICE, "Price lower than Base");
        require(priceUniInv > _BASE_PRICE, "Price Uni lower than Base");
        require(owner != address(0), "Not valid address" );
        uint256 totalPercent = teamPercent.add(liquidityPercent).add(_launchpadFeePercent.mul(2));
        require(totalPercent == _totalPercent, "Funds are distributed max 100 %");
        // setup UniLocked token
        _uniLocked = new UniswapLocked(uniRouter, releaseTime,  owner, priceUniInv);
        _softCap = softCap;
        _maxCap = maxCap;
        _start = start;
        _end = end;
        _liquidityPercent = liquidityPercent;
        _teamPercent = teamPercent;
        _priceInv = priceInv;
        _owner = owner;
        _releaseTime = releaseTime;
        _token = token;
        _teamWallet = teamWallet;
        _priceUniInv = priceUniInv;
    }

    /**
     * 
     */
    function end() public view returns (uint256) {
        return _end;
    }

       /**
     * 
     */
    function claimedAmount() public view returns (uint256) {
        return _claimedAmount;
    }

      /**
     * 
     */
    function start() public view returns (uint256) {
        return _start;
    }

     /**
     * 
     */
    function softCap() public view returns (uint256) {
        return _softCap;
    }
      /**
     * 
     */
    function maxCap() public view returns (uint256) {
        return _maxCap;
    }

     /**
     * 
     */
    function isSoldOut() public view returns (bool) {
        return _isSoldOut;
    }

     /**
     * 
     */
    function isRefunded() public view returns (bool) {
        return _isRefunded;
    }
    /**
     * 
     */
    function uniLocked() public view returns (address) {
        return address(_uniLocked);
    }



     /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceToClaim(address account) public view returns (uint256) {
        return _balancesToClaim[account];
    }
    /**
    * When receive ETH mint tokens internally and save a storage reference. 
    * Launchpad needs to not have refunded, and nethier sold out
    *
     */
    receive() external payable {
        require(block.timestamp > start() , "LaunchpadToken: not started yet");
        require(block.timestamp < end() , "LaunchpadToken: finished");
        require(_isRefunded == false , "LaunchpadToken: Refunded is activated");
        require(_isSoldOut == false , "LaunchpadToken: SoldOut");
        uint256 amount = msg.value;
        require(amount > 0, "LaunchpadToken: eth value sent needs to be above zero");
        _balancesToClaim[msg.sender] = _balancesToClaim[msg.sender].add(amount);
        _raisedETH = _raisedETH.add(amount);
        if(_raisedETH > _maxCap){
            _isSoldOut = true;
            uint256 refundAmount = _raisedETH.sub(_maxCap);
            if(refundAmount > 0){
                // Subtract value that is higher than maxCap
                _balancesToClaim[msg.sender] = _balancesToClaim[msg.sender].sub(refundAmount);
                payable(msg.sender).transfer(refundAmount);
            }
            emit SoldOut();
        }

        emit Received(msg.sender, amount);
    }

    /**
    * @dev Claim tokens to user, after release time
    * If project not reached softcap funds are returned back
    */
    function claim() public returns (bool)  {
        // if sold out no need to wait for the time to finish, make sure liquidity is setup
        require(block.timestamp >= end() || (!_isSoldOut && _isLiquiditySetup), "LaunchpadToken: sales still going on");
        require(_balancesToClaim[msg.sender] > 0, "LaunchpadToken: No tokens to claim");
       // require(_isRefunded != false , "LaunchpadToken: Refunded is activated");
        uint256 amount =  _balancesToClaim[msg.sender];
        _balancesToClaim[msg.sender] = 0;
        if(_isRefunded){
            // return back funds
            payable(msg.sender).transfer(amount);
            emit Refunded(msg.sender, amount);
            return true;
        }
        uint256 tokensToClaim = amount.mul(_priceInv).div(_BASE_PRICE);
        // Transfer Tokens to User
        _token.safeTransfer(msg.sender, tokensToClaim);
        _claimedAmount = _claimedAmount.add(amount);
        emit Claimed(msg.sender, amount);
        return true;
    }

    /**
    * Setup liquidity and transfer all amounts according to defined percents, if softcap not reached set Refunded flag
    */
    function setupLiquidity() public {
        require(_isSoldOut == true || block.timestamp > end() , "LaunchpadToken: not sold out or time not elapsed yet" );
        require(_isRefunded == false, "Launchpad: refunded is activated");
        //
        if(_raisedETH < _softCap){
            _isRefunded = true;
            return;
        }

        _uniLocked.setupToken(_token);
        uint256 ethBalance = address(this).balance;
        require(ethBalance > 0, "LaunchpadToken: eth balance needs to be above zero" );
        uint256 liquidityAmount = ethBalance.mul(_liquidityPercent).div(_totalPercent);
        uint256 tokensAmount = _token.balanceOf(address(this));
        require(tokensAmount >= liquidityAmount.mul(_priceInv).div(_BASE_PRICE), "Launchpad: Not sufficient tokens amount");
        uint256 teamAmount = ethBalance.mul(_teamPercent).div(_totalPercent);
        uint256 layerFeeAmount = ethBalance.mul(_launchpadFeePercent).div(_totalPercent);
        uint256 trustswapFeeAmount = ethBalance.mul(_launchpadFeePercent).div(_totalPercent);
        payable(_layerFeeAddress).transfer(layerFeeAmount);
        payable(_trustSwapFeeAddress).transfer(trustswapFeeAmount);
        payable(_teamWallet).transfer(teamAmount);
        payable(_uniLocked).transfer(liquidityAmount);
        _token.safeTransfer(address(_uniLocked), liquidityAmount.mul(_priceUniInv).div(_BASE_PRICE));
        _uniLocked.addLiquidity();
        _isLiquiditySetup = true;
    }

    /**
     * @notice Transfers non used tokens held by Lock to owner.
       @dev Able to withdraw funds after end time and liquidity setup, if refunded is enabled just let token owner 
       be able to withraw 
     */
    function release(IERC20 token) public {
        uint256 amount = token.balanceOf(address(this));
        if(_isRefunded){
             token.safeTransfer(_owner, amount);
        }
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp >= end() || _isSoldOut == true, "Launchpad: current time is before release time");
        require(_isLiquiditySetup == true, "Launchpad: Liquidity is not setup");
        // TO Define: Tokens not claimed should go back to time after release time?
        require(_claimedAmount == _raisedETH || block.timestamp >= _releaseTime, "Launchpad: Tokens still to be claimed");
        require(amount > 0, "Launchpad: no tokens to release");

        token.safeTransfer(_owner, amount);
    }

      /**
     * @dev Emitted when tokens are minted on the fallback Received
     *
     * Note that `value` may be zero.
     */
    event Received(address indexed from, uint256 value);
    /**
     * @dev Emitted when tokens are claimed by user
     *
     */
    event Claimed(address indexed from, uint256 value);
     /**
     * @dev Emitted when refunded if not successful
     *
     */
    event Refunded(address indexed from, uint256 value);


}