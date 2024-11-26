// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Console.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDecentralizedAXUSD} from "../../script/DeployDecentralizedAXUSD.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvariatTest is StdInvariant, Test {
    DeployDecentralizedAXUSD deployer;
    DecentralizedStableCoin axUsd;
    DSCEngine engine;
    HelperConfig config;
    address weth;
    address wbtc;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    Handler deFiHandler;

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
        deFiHandler = new Handler(engine, axUsd);
        targetContract(address(deFiHandler));
    }

    function invariant_testCollateralIsMoreThanTotalSupplyOFAXUSD() public {
        uint256 totalSupply = axUsd.totalSupply();
        uint256 totalWETHDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalBTCDeposited = IERC20(wbtc).balanceOf(address(engine));
        uint256 totalWETHinUSD = engine.getUsdValue(weth, totalWETHDeposited);
        uint256 totalWBTCinUSD = engine.getUsdValue(wbtc, totalBTCDeposited);
        assert(totalWBTCinUSD + totalWETHinUSD >= totalSupply);
        console.log("totalSupply", totalSupply);
        console.log("totalWETHinUSD", totalWETHinUSD);
        console.log("totalWBTCinUSD", totalWBTCinUSD);
        console.log("totalmintedCalled", deFiHandler.totalmintedCalled());
    }
}
