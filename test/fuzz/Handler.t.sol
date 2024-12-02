// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Console.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../Mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../Mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine engine;
    DecentralizedStableCoin axUsd;
    ERC20Mock weth;
    ERC20Mock wbtc;
    uint256 public totalmintedCalled;
    address[] public depositedAddresses;
    MockV3Aggregator ethPriceFeed;

    constructor(DSCEngine _engine, DecentralizedStableCoin _axusd) {
        engine = _engine;
        axUsd = _axusd;
        address[] memory collateralAddresses = _engine.getCollateralAddresses();
        weth = ERC20Mock(collateralAddresses[0]);
        wbtc = ERC20Mock(collateralAddresses[1]);
        ethPriceFeed = MockV3Aggregator(engine.getCollateralTokenPriceFeed(address(weth)));
    }

    function depositCollateral(uint256 collateralSeeds, uint256 amount) public {
        ERC20Mock collateral = _getCollateralAddress(collateralSeeds);
        uint256 amountToDeposit = bound(amount, 1, type(uint96).max);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountToDeposit);
        collateral.approve(address(engine), amountToDeposit);
        engine.depositCollateral(address(collateral), amountToDeposit);
        depositedAddresses.push(msg.sender);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        vm.startPrank(msg.sender);
        ERC20Mock collateral = _getCollateralAddress(collateralSeed);
        uint256 maxCollateralToRedeem = engine.getColleralBalanceofUser(msg.sender, address(collateral));
        if (maxCollateralToRedeem == 0) {
            return;
        }
        console.log("maxCollateralToRedeem", maxCollateralToRedeem);
        uint256 amountToReddem = bound(amountCollateral, 0, maxCollateralToRedeem);
        engine.redeemCollateral(address(collateral), amountToReddem);
        vm.stopPrank();
    }

    function mintAxusd(uint256 amount, uint256 addressSeeds) public {
        if (depositedAddresses.length == 0) {
            return;
        }
        address user = depositedAddresses[addressSeeds % depositedAddresses.length];
        (uint256 collateralValueInUsd, uint256 totalAxusdMinted) = engine.getUserAccountDetails(user);
        int256 maxAmountToMint = int256(collateralValueInUsd) / 2 - int256(totalAxusdMinted);
        if (maxAmountToMint <= 0) {
            return;
        }
        amount = bound(amount, 1, uint256(maxAmountToMint));
        if (amount == 0) {
            return;
        }
        vm.startPrank(user);
        engine.mintAXUSD(amount);
        vm.stopPrank();
        totalmintedCalled++;
    }

    function updateCollateralPrice(uint96 price) public {
        int256 priceInUsd = int256(uint256(price));
        ethPriceFeed.updateAnswer(priceInUsd);
    }

    function _getCollateralAddress(uint256 seed) internal view returns (ERC20Mock) {
        if (seed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
