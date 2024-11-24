// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeployDecentralizedAXUSD} from "../../script/DeployDecentralizedAXUSD.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../Mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDecentralizedAXUSD deployer;
    DecentralizedStableCoin axUsd;
    DSCEngine engine;
    HelperConfig config;
    address weth;
    address wbtc;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    uint256 public constant COLLATERAL_AMOUNT = 1000e18;
    uint256 public constant STARTING_ERC_BALANCE = 9999e18;
    address user = address(1);

    function setUp() public {
        deployer = new DeployDecentralizedAXUSD();
        (axUsd, engine, config) = deployer.run();
        (
            weth,
            wbtc,
            wethUsdPriceFeed,
            wbtcUsdPriceFeed,
            /**
             * uint256 deployerKey
             */
        ) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(user, STARTING_ERC_BALANCE);
    }
    ////////////////////
    // Test cases///////
    ////////////////////

    function testTokenToUSDValue() public {
        uint256 EthAmount = 1000e18;

        uint256 actualPrice = engine.getUsdValue(weth, EthAmount);
        uint256 expectedPrice = 3000000e18;
        assertEq(actualPrice, expectedPrice);
    }

    function testFailsIfCollateralisZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        vm.expectRevert();
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
