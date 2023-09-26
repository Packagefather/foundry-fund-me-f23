// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";


contract FundMeTest is Test {
   
    FundMe fundMe;

    address USER = makeAddr('Alice');
    uint256 constant SEND_VALUE= 0.1 ether;
    uint256 constant STARTING_BAL= 10 ether;
    uint256 constant GAS_PRICE = 1;
    /*
    NB: All functions are called by the FundMeTest(this) contract,
    except we use vm.prank to say it is our USER we want to be the 
    caller of the function. 

    However, FundMeTest is different from msg.sender. 
    msg.sender has a default value of : 
    DefaultSender: [0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38]
    */
    function setUp() external {
        
        //fundMe = new FundMe(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        //owner of this contract will be 
        //DefaultSender: [0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38]
        //as set when we initialized vm.startBroadcast in DeployFundMe.sol
        vm.deal(USER, STARTING_BAL);

    }

    function testMinDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
        console.log("The Minimum_USD in the contract is currently", fundMe.MINIMUM_USD(),", So it is correct if it is 5000000000000000000");
    }

    function testOwnerIsMsgSender() public {
        console.log("This is FundMe owner: ",fundMe.getOwner(),", this is msg.sender: ",msg.sender);
        console.log("this would be the address of this contract FundMeTest:", address(this));
        assertEq(fundMe.getOwner(), msg.sender); //this works 
        //because we have returned the msg.sender in the deployment script when
        //vm.startBoradcast runs. it sets the true message sender 
        //assertEq(fundMe.i_owner(), address(this)); 
        //rememebr that it is FundMeTest contract that deployed FundMe not msg.sender
        
    }

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFunctionFailsWithoutEnoughETH() public {
        vm.expectRevert(); //the nextline should revert!
        fundMe.fund(); //send 0 value instead of sending MINIMUM_USD value
    }

    function testFundUpdateFundedDataStructure() public {
        console.log("USER:>>> ",USER);
        vm.prank(USER);
        /*
        When called, it sets msg.sender to the specified address for the next tx call
        The purpose of this function seems to be to change the 
        calling context temporarily, making it appear 
        as if the specified address is the sender of the next function call.
        */
        fundMe.fund{value:SEND_VALUE}();
        fundMe.fund{value:SEND_VALUE}();
        //Initially, this function is called by the FundMeTest contract,
        //but to simulate as if its an address calling it
        //we will use vm.prank to say that the next call is done
        //by the USER we created
        console.log("msg.sender:>>> ",msg.sender); //without pranking, here would be FundMeTest contract
        console.log("address(this):>>> ",address(this));
        //uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        uint256 amountFunded = fundMe.getAddressToAmountFunded(address(this));
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        
        console.log("The DefaultSender interracting now:>>> ",msg.sender);
        console.log("USER:>>> ",USER);
        vm.prank(USER);
        console.log("The Newly set msg.sender:>>> ",msg.sender);
        //this won't set msg.sender to USER because msg.sender by 
        //default has a value we cannot change,
        //the vm.prank(USER) on sets msg.sender to the next tx call
        //temporarily. which takes effect on the tx function call below
        fundMe.fund{value: SEND_VALUE}();
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }


    modifier funded(){
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded{
        //vm.prank(USER); //this user is different from the one below, 
        //each time prank is called, it creates a new user
        //fundMe.fund{value: SEND_VALUE}(); ----modifier has handled this, so we dont repeat it everytime

        vm.prank(USER);
        vm.expectRevert(); 
        //This test will pass because indeed it is not this user 
        //that is the owner, 
        //owner is DefaultSender: [0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38]
        fundMe.withdraw();

    }

    function testWithdrawWithSingleFunder() public funded{
        //Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance; //this balance part is normal solidity thing
        //rememebr we can do address(this).balance, thats what is happening there
        uint256 startingFundMeBalance = address(fundMe).balance;
        //Note that, at this point, the fundMe contract has been funded already with SEND_VALUE
        //while the owner balance is what it is at the moment. 
        //So after withdrawal the owner balance at starting plus fundMe balance at starting
        //should be equal to owner ending balance, since fundMe balance has now moved to owner

        //Act
        // uint256 gasStart = gasleft();
        // vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // uint256 gasEnd = gasleft();
        // uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        // console.log(gasUsed);


        //Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(startingFundMeBalance + startingOwnerBalance, endingOwnerBalance);
        
    }

 
    function testWithdrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        //we are using 160 because from v8.0 address(...) must take uint160 as 
        //it can no longer explicitly convert uint256 to address format
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++){
            hoax(address(i), SEND_VALUE);
            //hoax does the same thing as prank(user), then deal. It does these two in one call
            fundMe.fund{value:SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        vm.startPrank(fundMe.getOwner());
        //startpPrank and stopPrank are just like broadcast, it assumes everything
        //from the next line to be done be the newly inserted address into the startPrank
        fundMe.withdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);

    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        uint160 numberOfFunders = 10;
        //we are using 160 because from v8.0 address(...) must take uint160 as 
        //it can no longer explicitly convert uint256 to address format
        uint160 startingFunderIndex = 1; //0 is alwasy address(0) and we dont want to use that
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++){
            hoax(address(i), SEND_VALUE);
            //hoax does the same thing as prank(user), then deal. It does these two in one call
            fundMe.fund{value:SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        vm.startPrank(fundMe.getOwner());
        //startpPrank and stopPrank are just like broadcast, it assumes everything
        //from the next line to be done be the newly inserted address into the startPrank
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);

    }
}