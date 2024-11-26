// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

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

    ////////////////////////////
    ////constructor testing////
    ////////////////////////////
    address[] priceFeeds;
    address[] tokens;

    function testCheckifTokenAddressLengthisNotEqualToPriceFeeds() public {
        priceFeeds.push(wethUsdPriceFeed);
        // priceFeeds.push(wbtcUsdPriceFeed);
        tokens.push(weth);
        tokens.push(wbtc);
        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine__tokenAddressesNotEqualtoPricefeedAddresses.selector)
        );
        new DSCEngine(tokens, priceFeeds, address(axUsd));
    }

    ////////////////////
    /////price tests////
    ////////////////////

    function testGetColleralAmountFromUSD() public {
        uint256 USD = 3000e18;
        uint256 actualCollateral = engine.getColleralAmountFromUSD(weth, USD);
        assertEq(actualCollateral, 1e18);
    }

    function testTokenToUSDValue() public {
        uint256 EthAmount = 1000e18;

        uint256 actualPrice = engine.getUsdValue(weth, EthAmount);
        uint256 expectedPrice = 3000000e18;
        assertEq(actualPrice, expectedPrice);
    }

    /////////////////////////
    ////collateral tests////
    /////////////////////////

    function testFailsIfCollateralisZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);

        vm.expectRevert(abi.encodeWithSignature("Error(string)", string("fail")));
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testFailsIfCollateralIsNoTAllowd() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        vm.expectRevert();
        engine.depositCollateral(address(8), 5);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        engine.depositCollateral(weth, COLLATERAL_AMOUNT / 2);
        vm.stopPrank();
        _;
    }

    function testCanDepositAndGetUserAccountInfo() public depositedCollateral {
        (uint256 totalCollateralValueinUSD, uint256 totalAXUDminted) = engine.getUserAccountDetails(user);
        uint256 acutalCollateralAmount = engine.getColleralAmountFromUSD(weth, totalCollateralValueinUSD);
        assertEq(totalAXUDminted, 0);
        assertEq(COLLATERAL_AMOUNT / 2, acutalCollateralAmount);
    }
}
