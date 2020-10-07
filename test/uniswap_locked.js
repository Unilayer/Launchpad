const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const { expect } = require('chai');


// Import utilities from Test Helpers
const { BN, expectEvent, expectRevert, send, ether, time, balance } = require('@openzeppelin/test-helpers');

// console.log(uniswapV2PeripheryLoader)
// Load compiled artifacts
const Token = contract.fromArtifact('ERC20Template');
const Launchpad = contract.fromArtifact('Launchpad');
const UniswapLocked = contract.fromArtifact('UniswapLocked');
// const Router = uniswapV2PeripheryLoader.web3.fromArtifact('UniswapV2Router02');
const Router = contract.fromArtifact('UniswapV2Router02');
const Factory = contract.fromArtifact('UniswapV2Factory');
const Weth = contract.fromArtifact('WETH9');


// Start test block
describe('UniswapLocked', async function () {
    const [ owner, user1, user2, user3, user4 ] = accounts;
   
      
    const totalSupply = ether('1').mul(new BN('1000'));
    const BASE_PRICE = new BN('100000');
    // price is 1/10
    const priceInv = new BN('10').mul(BASE_PRICE);
    const priceInvUni = new BN('20').mul(BASE_PRICE);
    const endTime  = 5*3600;
    const startTime  = 30;
    const releaseTime = 10*3600;
    
    beforeEach(async function () {
      this.contract = await Token.new('Test', 'Tst', { from: owner });
      this.factory = await Factory.new(user1, {from: owner});
      this.weth = await Weth.new({from:owner});
      this.router = await Router.new(this.factory.address, this.weth.address, {from: owner});
      const currentTime  = (await time.latest()).toNumber();     
      const start = currentTime + startTime;
      const end = currentTime + endTime;
      const release = currentTime + releaseTime;
     // console.log(currentTime.toNumber());
      //console.log(start);
      
      this.launchpad = await Launchpad.new(this.router.address, this.contract.address, priceInvUni.toString(), priceInv.toString(),  user1, user2, ether('1'), ether('5'), 2000, 7500, end, start, release, {from: owner});
      const uniLockedAdress = await this.launchpad.uniLocked();
      this.uniLocked = await UniswapLocked.at(uniLockedAdress);

    // User wants to sell 80 % of supply
      this.contract.transfer(this.launchpad.address, ether('1').mul(new BN('800')), {from: owner});
    
    });
    // Test case
    it('User should be able to send ETH and claimed amount be correct ', async function () {
      // Go to finish the time
      await time.increase(time.duration.seconds(startTime+1));
      const amount = ether('1');
      await send.ether(user1 , this.launchpad.address, amount )

      expect((await this.launchpad.balanceToClaim(user1)).toString()).to.equal(amount.toString());
    });

    // Test case
    it('Should sell out if value is higher than cap ', async function () {
      // Go to finish the time
      await time.increase(time.duration.seconds(startTime+1));
      const amount = ether('5.1');
      await send.ether(user1 , this.launchpad.address, amount );
      expect((await this.launchpad.isSoldOut())).to.equal(true);

      expect((await this.launchpad.balanceToClaim(user1)).toString()).to.equal(amount.toString());
    });


     // Test case
     it('Is able to setup liquidity when launchpad finished', async function () {
        // Go to finish the time
        await time.increase(time.duration.seconds(startTime+1));
      const amount = ether('2');
      await send.ether(user1 , this.launchpad.address, amount );
       // Go to finish the time
      await time.increase(time.duration.seconds(endTime+1));
      const uniLockedAdress = await this.launchpad.uniLocked();
   
      await this.launchpad.setupLiquidity();
     
      const ethBalance = await balance.current(uniLockedAdress)
      expect((await this.contract.balanceOf(uniLockedAdress)).toString() ).to.equal(amount.mul(priceInvUni).div(BASE_PRICE).mul(new BN('2000')).div(new BN('10000')).toString()); 
      expect(ethBalance.toString() ).to.equal(amount.mul(new BN('2000')).div(new BN('10000')).toString());

      await this.uniLocked.addLiquidity();
     
    });

     // Test case
     it('Is able to claim tokens when launchpad finished', async function () {
    
      await time.increase(time.duration.seconds(startTime+1));
      const amount = ether('2');
      await send.ether(user1 , this.launchpad.address, amount );
       // Go to finish the time
      await time.increase(time.duration.seconds(endTime+1));
      await this.launchpad.claim({from:user1});
      expect((await this.contract.balanceOf(user1)).toString() ).to.equal(amount.mul(priceInv).div(BASE_PRICE).toString());
      expect((await this.launchpad.claimedAmount()).toString() ).to.equal(amount.toString());
      
    });

  });


  