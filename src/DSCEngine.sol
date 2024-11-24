// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
    error DSCEngine__BelowTheHealthFactor(uint256 healthFactor);
    error DSCEngine__NotMinted();

    ///////////////////////
    // State variables   //
    ///////////////////////

    uint256 public constant ADDITIONAL_PRECISION = 1e10;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATE_THRESHOLD = 50;
    uint256 public constant LIQUIDATE_PRECISON = 100;
    uint256 public constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) public s_priceFeeds;
    mapping(address user => mapping(address tokenCollateralAddress => uint256 amount)) public s_collateralDeposited;
    mapping(address user => uint256 amount) private s_axusdMinted;

    address[] private s_collateralTokens;

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
            s_collateralTokens.push(tokenAddresses[i]);
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
    /**
     * @param amountToBeMinted amount of AXUSD to be minted
     * should only be minted if collateral> amountToBeMinted
     */

    function mintAXUSD(uint256 amountToBeMinted) public notZeroAmount(amountToBeMinted) nonReentrant {
        s_axusdMinted[msg.sender] += amountToBeMinted;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool isMinted = i_stableCoinContractAddress.mint(msg.sender, amountToBeMinted);
        if (!isMinted) {
            revert DSCEngine__NotMinted();
        }
    }

    function burnAXUSD() public {}

    function liquidate() public {}

    function getHealthFactor() public {}

    /**
     * @param user address of the user
     * @dev reverts if health factor is less than 1
     */
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BelowTheHealthFactor(userHealthFactor);
        }
    }

    /**
     * @param user address of the user
     * @return ratio of collateral to minted AXUSD
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalCollateralValue, uint256 totalAXUSDMinted) = _getUserAccountDetails(user);
        uint256 collateralAdjustedForTheshold = totalCollateralValue * LIQUIDATE_THRESHOLD / LIQUIDATE_PRECISON;

        return collateralAdjustedForTheshold * PRECISION / totalAXUSDMinted;
    }

    function _getUserAccountDetails(address user)
        private
        view
        returns (uint256 totalCollateralValue, uint256 totalAXUSDMinted)
    {
        totalAXUSDMinted = s_axusdMinted[user];
        totalCollateralValue = getUserCollateralValue(user);
    }

    /**
     * @param user address of the token
     * @return totalCollateralValueUSD total value of all the collateral in USD
     * @dev loops through all the collateral tokens and gets the USD value of each token and adds it to totalCollateralValueUSD
     *
     */
    function getUserCollateralValue(address user) public view returns (uint256 totalCollateralValueUSD) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueUSD += getUsdValue(token, amount);
        }
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH =3000 USD
        // return value from chainlink is 3000 * 10^8
        return ((uint256(price) * ADDITIONAL_PRECISION) * amount) / PRECISION;
    }
}
