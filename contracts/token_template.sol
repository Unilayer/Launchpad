// contracts/DexKit.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./uniswap_locked.sol";

contract LaunchpadToken is ERC20, AccessControl, ERC20Capped {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
   
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

      /**
     * @dev  emitted when sold out
     *
     */
    event SoldOut();

    uint256 private constant _totalPercent = 10000;
    // Layer charges 2.5 % and TrustSwap another 2.5%
    uint256 private constant _launchpadFeePercent = 250;

    address private constant _layerFeeAddress = '0xassad';

    address private constant _trustSwapFeeAddress = '0xassad';

    mapping (address => uint256) private _balancesToClaim;

    uint256 private _liquidityLock;

    uint256 private _mintedLiquidity;

    uint256 private _percentLiquidity;

    uint256 private _end;

    uint256 private _start;
     
    uint256 private _price;

    bool    private _isRefunded = false;

    bool    private _isSoldOut = false;

    bool    private _isLiquiditySetup = false;

    uint256 private _raisedETH;

    uint256 private _softCap;

    uint256 private _maxCap;

    address private _teamWallet;

    UniswapLockedOnMint private _uniLocked;

    constructor(uint256 priceUni, uint256 price uint256 initialSupply, address owner, address teamWallet, uint256 softCap, uint256 maxCap, uint256 percentLiquidity, uint256 percentTeam, uint256 end, uint256 start) public ERC20("Token", "TKN") {
        require(start > block.timestamp, "start time above current time");
        require(end > start, "End time above start time");
        require(percentLiquidity < 3000, "Max Liquidity allowed is 30 %")
        uint256 totalPercent = percentTeam.add(percentLiquidity).add(500);
        require(totalPercent == _totalPercent, "Funds are distributed max 100 %")
      
        // mint presale for owner
        if(initialSupply > 0){
           _mint(owner, initialSupply);
        }
        // setup UniLocked token
        _uniLocked = new UniswapLockedOnMint(uniRouter, address(this), releaseTime, _msgSender(), priceUni);

        _setupRole(MINTER_ROLE, _uniLocked);
        _softCap = softCap;
        _maxCap = maxCap;
        _start = start;
        _end = end;
        _percentLiquidity = percentLiquidity;
        _percentTeam = percentTeam;
        _price = price;
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
     * @dev See {IERC20-balanceOf}.
     */
    function balanceToClaim(address account) public view returns (uint256) {
        return _balancesToClaim[account];
    }
    /**
    * When receive ETH mint tokens internally and save a storage reference
    *
     */
    receive() external payable {
        require(_isRefunded != false , "LaunchpadToken: Refunded is activated");
        require(_isSoldOut != false , "LaunchpadToken: SoldOut");
        uint256 amount = msg.value;
        require(amount > 0, "LaunchpadToken: eth value sent needs to be above zero");
        _balancesToClaim[_msgSender()] = _balancesToClaim[_msgSender()].add(amount);
        _raisedETH = _raisedETH.add(amount);
        if(_raisedETH > _maxCap){
            _isSoldOut = true;
            emit SoldOut();
        }

        emit Received(_msgSender(), amount);
    }

    /**
    * @dev Claim tokens to user, after release time
    */
    function claim() public returns (bool)  {
        // if sold out no need to wait for the time to finish, make sure liquidity is setup
        require(block.timestamp >= _end || (!_isSoldOut && _isLiquiditySetup), "LaunchpadToken: sales still going on");
        require(_balancesToClaim[_msgSender()] > 0, "LaunchpadToken: No tokens to claim");
       // require(_isRefunded != false , "LaunchpadToken: Refunded is activated");
        uint256 amount =  _balancesToClaim[_msgSender()];
        _balancesToClaim[_msgSender()] = 0;
        if(_isRefunded){
            // return back funds
            payable(_msgSender()).transfer(amount);
            emit Refunded(refundedAmount, _msgSender());
            return true;
        }
        
        // Mint tokens to user
        _mint(_msgSender(), amount.mul(_price));
        emit Claimed(_msgSender(), amount);
        return true
    }

    /**
    * Setup liquidity by the contract deployer
    */
    function setupLiquidity() public {
        require(_isSoldOut == true || block.timestamp> end , "LaunchpadToken: not sold out or time not elapsed yet" );
        uint256 ethBalance = address(this).balance;
        require(ethBalance > 0, "LaunchpadToken: eth balance needs to be above zero" );
        uint256 liquidityAmount = ethBalance.mul(_liquidityPercent).div(_totalPercent);
        uint256 teamAmount = ethBalance.mul(_teamPercent).div(_totalPercent);
        uint256 layerFeeAmount = ethBalance.mul(_launchpadFeePercent).div(_totalPercent);
        uint256 trustswapFeeAmount = ethBalance.mul(_launchpadFeePercent).div(_totalPercent);
        require(_layerFeeAddress.send(layerFeeAmount));
        require(_trustSwapFeeAddress.send(trustswapFeeAmount));
        require(_teamWallet.send(teamAmount));
        require(_uniLocked.send(liquidityAmount));
        _uniLocked.addLiquidity();
        _isLiquiditySetup = true;
    }
     /**
     * @dev Creates `amount` new tokens for `to`, of token type `id`.
     *
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 id, uint256 amount, bytes memory data) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "LaunchpadToken: must have minter role to mint");

        _mint(to, id, amount, data);
    }

  
}