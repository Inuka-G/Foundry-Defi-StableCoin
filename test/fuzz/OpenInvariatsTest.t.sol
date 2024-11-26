// // SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity ^0.8.19;

// import {Test} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DeployDecentralizedAXUSD} from "../../script/DeployDecentralizedAXUSD.s.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract OpenInvariatTest is StdInvariant, Test {
//     DeployDecentralizedAXUSD deployer;
//     DecentralizedStableCoin axUsd;
//     DSCEngine engine;
//     HelperConfig config;
//     address weth;
//     address wbtc;
//     address wethUsdPriceFeed;
//     address wbtcUsdPriceFeed;

//     function setUp() public {
//         deployer = new DeployDecentralizedAXUSD();
//         (axUsd, engine, config) = deployer.run();
//         (
//             weth,
//             wbtc,
//             wethUsdPriceFeed,
//             wbtcUsdPriceFeed,
//             /**
//              * uint256 deployerKey
//              */
//         ) = config.activeNetworkConfig();
//         targetContract(address(engine));
//     }

//     function invariant_testCollateralIsMoreThanTotalSupplyOFAXUSD() public {
//         uint256 totalSupply = axUsd.totalSupply();
//         uint256 totalWETHDeposited = IERC20(weth).balanceOf(address(engine));
//         uint256 totalBTCDeposited = IERC20(wbtc).balanceOf(address(engine));
//         uint256 totalWETHinUSD = engine.getUsdValue(weth, totalWETHDeposited);
//         uint256 totalWBTCinUSD = engine.getUsdValue(wbtc, totalBTCDeposited);
//         assert(totalWBTCinUSD + totalWETHinUSD >=    totalSupply);
//     }
// }
