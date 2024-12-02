// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./lib/OracleLib.sol";

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
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorIsFine();

    ///////////////////////
    // State variables   //
    ///////////////////////

    uint256 public constant ADDITIONAL_PRECISION = 1e10;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATE_THRESHOLD = 50;
    uint256 public constant LIQUIDATE_PRECISON = 100;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATE_BONUS = 10;

    mapping(address token => address priceFeed) public s_priceFeeds;
    mapping(address user => mapping(address tokenCollateralAddress => uint256 amount)) public s_collateralDeposited;
    mapping(address user => uint256 amount) private s_axusdMinted;

    address[] private s_collateralTokens;

    DecentralizedStableCoin public immutable i_stableCoinContractAddress;

    ///////////////
    // Events    //
    ///////////////
    using OracleLib for AggregatorV3Interface;

    event CollateralDeposited(address indexed user, address indexed tokenCollateralAddress, uint256 amountColletaral);
    event CollateralRedeemed(
        address indexed from, address indexed to, address indexed tokenCollateralAddress, uint256 amount
    );

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

    function depositCollateralAndMintAXUSD(
        address tokenCollateralAddress,
        uint256 amountColletaral,
        uint256 amountToBeMinted
    ) external {
        depositCollateral(tokenCollateralAddress, amountColletaral);
        mintAXUSD(amountToBeMinted);
    }

    /**
     * @param tokenCollateralAddress address of the token to be deposited as collateral (weth or wbtc contract address)
     * @param amountColletaral amount of token to be deposited as collateral
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountColletaral)
        public
        notZeroAmount(amountColletaral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        // deposit the collateral and add already deposited amount +=
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountColletaral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountColletaral);
        IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountColletaral);
    }

    function redeemCollateralForAXUSD(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountToBurn)
        public
    {
        burnAXUSD(amountToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // redeem collateral already check revertIfHealthFactorIsBroken
    }

    function redeemCollateral(address tokenCollateralAddress, uint256 amount)
        public
        notZeroAmount(amount)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amount);

        _revertIfHealthFactorIsBroken(msg.sender);
    }
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

    function burnAXUSD(uint256 amountTobeBurn) public notZeroAmount(amountTobeBurn) nonReentrant {
        _burnAXUSD(msg.sender, msg.sender, amountTobeBurn);
        _revertIfHealthFactorIsBroken(msg.sender);
    }
    /*
     * @param collateral: The ERC20 token address of the collateral you're using to make the protocol solvent again.
     * This is collateral that you're going to take from the user who is insolvent.
     * In return, you have to burn your DSC to pay off their debt, but you don't pay off your own.
     * @param user: The user who is insolvent. They have to have a _healthFactor below MIN_HEALTH_FACTOR
     * @param debtToCover: The amount of DSC you want to burn to cover the user's debt.
     *
     * @notice: You can partially liquidate a user.
     * @notice: You will get a 10% LIQUIDATION_BONUS for taking the users funds.
     * @notice: This function working assumes that the protocol will be roughly 150% overcollateralized in order for this to work.
     * @notice: A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate anyone.
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     */

    function liquidate(address tokenCollateralAddress, address user, uint256 debtToCover)
        public
        notZeroAmount(debtToCover)
        nonReentrant
    {
        uint256 startingHealthFactor = _healthFactor(user);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsFine();
        }
        // amount of eth to cover the debt
        uint256 tokenColleralAmountFromUSD = getColleralAmountFromUSD(tokenCollateralAddress, debtToCover);
        // giving a 10% bonus
        uint256 bonusColleteralAmount = tokenColleralAmountFromUSD * LIQUIDATE_BONUS / LIQUIDATE_PRECISON;
        uint256 totalCollateralAmount = tokenColleralAmountFromUSD + bonusColleteralAmount;
        _redeemCollateral(user, msg.sender, tokenCollateralAddress, totalCollateralAmount);
        _burnAXUSD(user, msg.sender, debtToCover);
        uint256 endingHealthFactor = _healthFactor(user);
        if (endingHealthFactor <= MIN_HEALTH_FACTOR) {
            revert DSCEngine__BelowTheHealthFactor(endingHealthFactor);
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getColleralAmountFromUSD(address tokenCollateralAddress, uint256 usdAmountInWei)
        public
        view
        returns (uint256)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[tokenCollateralAddress]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_PRECISION);
    }

    function getHealthFactor() public {}
    ////////////////////////////
    // Internal functions    //
    ////////////////////////////

    function _burnAXUSD(address onBehalf, address from, uint256 amountTobeBurn) internal {
        s_axusdMinted[onBehalf] -= amountTobeBurn;
        bool success = i_stableCoinContractAddress.transferFrom(from, address(this), amountTobeBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_stableCoinContractAddress.burn(amountTobeBurn);
    }

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 collateralAmount)
        internal
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= collateralAmount;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, collateralAmount);
        bool success = IERC20(tokenCollateralAddress).transfer(to, collateralAmount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

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
        if (totalAXUSDMinted == 0) return type(uint256).max;
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
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        // 1 ETH =3000 USD
        // return value from chainlink is 3000 * 10^8
        return ((uint256(price) * ADDITIONAL_PRECISION) * amount) / PRECISION;
    }

    function getUserAccountDetails(address user)
        public
        view
        returns (uint256 totalCollateralValue, uint256 totalAXUSDMinted)
    {
        (totalCollateralValue, totalAXUSDMinted) = _getUserAccountDetails(user);
    }

    function getCollateralAddresses() public view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getColleralBalanceofUser(address user, address tokenCollateralAddress) public view returns (uint256) {
        return s_collateralDeposited[user][tokenCollateralAddress];
    }
    function getCollateralTokenPriceFeed(address tokenCollateralAddress) public view returns (address) {
        return s_priceFeeds[tokenCollateralAddress];
    }
}
