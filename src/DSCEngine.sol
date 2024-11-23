// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

/**
 * @title DSC Engine contract
 * @author inukaG on behalf of axion chain labs
 * @notice this is the engine of our stablecoin system loosely based on Dai stablecoin MakerDao protocol
 * this stablecoin is AXUSD
 * - doller pedged
 * - algorithmic
 * - overcollateralized by wEth and wBTC
 *
 * this stablecoin is similar to DAI if dai had no governance backed only by wEth and wBTC and no fees
 * 1 token == 1 doller
 * overcollateralized ->> always colletaral > total token value
 *
 * this contract responsible for minting and burning of stablecoin tokens and deposit and withdraw of collateral
 */

contract DSCEngine {
    function depositCollateralAndMintAXUSD() public {}

    function depositCollateral() public {}

    function redeemCollateralForAXUSD() public {}

    function redeemCollateral() public {}

    function mintAXUSD() public {}

    function burnAXUSD() public {}

    function liquidate() public {}

    function getHealthFactor() public {}
}
