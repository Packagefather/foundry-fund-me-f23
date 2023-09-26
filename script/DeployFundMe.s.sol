// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";
import {HelperConfig} from "./HelperConfig.s.sol";


contract DeployFundMe is Script{

    function run() external returns (FundMe){

        //Before startBroadcast  --> Not a 'real' tx, but a simulation
        HelperConfig helperConfig = new HelperConfig();
        //we are doing here cause we do not want to spend gas on this
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();


        //After startBroadcast --> Real tx!
        vm.startBroadcast();
        //vm.startBroadcast sets the msg.sender to the person actually sending,
        //i.e DefaultSender: [0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38]
        //else it is the DeployFundMe contract that becomes msg.sender
        FundMe fundMe = new FundMe(ethUsdPriceFeed);
        vm.stopBroadcast();
        return fundMe;

    }
}