// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Decentralized Stable Coin contract
 * @author inukaG on behalf of axion chain labs
 * @notice this is erc20 implementation of our stablecoin system
 *
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__InvalidAmount();
    error DecentralizedStableCoin__NotEnoughTokensOwned();
    error DecentralizedStableCoin__InvalidAddress();

    constructor() ERC20("Axion Stable Coin", "AXUSD") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balanceOfSender = balanceOf(msg.sender);
        if (_amount == 0) {
            revert DecentralizedStableCoin__InvalidAmount();
        }
        if (balanceOfSender < _amount) {
            revert DecentralizedStableCoin__NotEnoughTokensOwned();
        }
        super.burn(_amount);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__InvalidAddress();
        }
        if (_amount == 0) {
            revert DecentralizedStableCoin__InvalidAmount();
        }
        _mint(_to, _amount);
        return true;
    }
}
