// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract APPositionToken is ERC20 {
    address public market;

    constructor(
        string memory _name,
        string memory _symbol,
        address _market
    ) ERC20(_name, _symbol) {
        market = _market;
    }

    modifier onlyMarket() {
        require(msg.sender == market, "Not market");
        _;
    }

    function mint(address to, uint256 amount) external onlyMarket {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyMarket {
        _burn(from, amount);
    }
}