// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

///////////////////////////////////////////////////
// Developed by Axion chain labs  //////////////////
///////////////////////////////////////////////////

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
contract DSCEngine is ReentrancyGuard {
    ///////////////
    // Errors    //
    ///////////////
    error DSCEngine__InvalidAmount();
    error DSCEngine__tokenAddressesNotEqualtoPricefeedAddresses();
    error DSCEngine__NotAllowedToken();
    ///////////////////////
    // State variables   //
    ///////////////////////

    mapping(address token => address priceFeed) public s_priceFeeds;
    mapping(address user => mapping(address tokenCollateralAddress => uint256 amount)) public s_collateralDeposited;

    DecentralizedStableCoin public immutable i_stableCoinContractAddress;

    ///////////////
    // Events    //
    ///////////////

    event CollateralDeposited(address indexed user, address indexed tokenCollateralAddress, uint256 amountColletaral);

    ///////////////
    // Modifiers //
    ///////////////

    modifier notZeroAmount(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__InvalidAmount();
        }
        _;
    }

    modifier isAllowedToken(address tokenContractAddress) {
        if (s_priceFeeds[tokenContractAddress] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    ///////////////
    // Functions //
    ///////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address axionStableCoinAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__tokenAddressesNotEqualtoPricefeedAddresses();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }
        i_stableCoinContractAddress = DecentralizedStableCoin(axionStableCoinAddress);
    }

    function depositCollateralAndMintAXUSD() external {}

    /**
     * @param tokenCollateralAddress address of the token to be deposited as collateral (weth or wbtc contract address)
     * @param amountColletaral amount of token to be deposited as collateral
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountColletaral)
        external
        notZeroAmount(amountColletaral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        // deposit the collateral and add already deposited amount +=
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountColletaral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountColletaral);
        IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountColletaral);
    }

    function redeemCollateralForAXUSD() public {}

    function redeemCollateral() public {}

    function mintAXUSD() public {}

    function burnAXUSD() public {}

    function liquidate() public {}

    function getHealthFactor() public {}
}
