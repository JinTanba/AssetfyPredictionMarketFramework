// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "@assetfy/ARCSMarket.sol";
import "../src/APPositionToken.sol";
import "../src/interfaces/UniswapV2.sol";

contract AssetfyPrediction {
    bool public resolved;
    bool public yesWins;
    bool private _initialized; 

    IERC20 public collateral;
    APPositionToken public yesToken;
    APPositionToken public noToken;
    IUniswapV2Router02 public router;
    address public yesNoPair;
    address public oracle;
    address public arcsMarketAddress;

    uint256 public totalCollateral;
    uint256 public projectId;


    constructor() {
    }

    function initialize(
        address _collateral,
        address _router,
        address _oracle,
        string memory _yesName,
        string memory _yesSymbol,
        string memory _noName,
        string memory _noSymbol,
        address _arcsMarketAddress,
        uint256 _projectId
    ) external {
        require(!_initialized, "Already initialized");
        _initialized = true;

        collateral = IERC20(_collateral);
        router = IUniswapV2Router02(_router);
        oracle = _oracle;
        arcsMarketAddress = _arcsMarketAddress;
        projectId = _projectId;

        yesToken = new APPositionToken(_yesName, _yesSymbol, address(this));
        noToken = new APPositionToken(_noName, _noSymbol, address(this));

        address factory = router.factory();
        yesNoPair = IUniswapV2Factory(factory).createPair(
            address(yesToken),
            address(noToken)
        );
    }

    event Split(address indexed user, uint256 amountCollateral);
    event Merge(address indexed user, uint256 amountPositions);
    event MarketResolved(bool yesWins);
    event ClaimedWinnings(address indexed user, uint256 amount);

    function split(uint256 amount) external {
        require(!resolved, "Market already resolved");
        require(amount > 0, "Invalid amount");

        bool success = collateral.transferFrom(msg.sender, address(this), amount);
        require(success, "Collateral transfer failed");

        totalCollateral += amount;

        yesToken.mint(msg.sender, amount);
        noToken.mint(msg.sender, amount);

        emit Split(msg.sender, amount);
    }

    function merge(uint256 amount) external {
        require(!resolved, "Market already resolved");
        require(amount > 0, "Invalid amount");

        yesToken.burn(msg.sender, amount);
        noToken.burn(msg.sender, amount);

        totalCollateral -= amount;

        bool success = collateral.transfer(msg.sender, amount);
        require(success, "Collateral transfer failed");

        emit Merge(msg.sender, amount);
    }

    function provideLiquidity(uint256 yesAmount, uint256 noAmount) external {
        require(!resolved, "Market already resolved");
        require(
            yesToken.transferFrom(msg.sender, address(this), yesAmount),
            "YES transfer fail"
        );
        require(
            noToken.transferFrom(msg.sender, address(this), noAmount),
            "NO transfer fail"
        );

        yesToken.approve(address(router), yesAmount);
        noToken.approve(address(router), noAmount);

        router.addLiquidity(
            address(yesToken),
            address(noToken),
            yesAmount,
            noAmount,
            0,
            0,
            msg.sender,
            block.timestamp
        );
    }

    function resolveMarket(bool _yesWins) external {
        require(msg.sender == oracle, "Only oracle can resolve");
        require(!resolved, "Already resolved");

        resolved = true;
        yesWins = _yesWins;

        emit MarketResolved(_yesWins);
    }

    function claimWinnings(uint256 amount) external {
        require(resolved, "Market not resolved");
        require(amount > 0, "Invalid amount");

        if (yesWins) {
            yesToken.burn(msg.sender, amount);
        } else {
            noToken.burn(msg.sender, amount);
        }

        totalCollateral -= amount;

        bool success = collateral.transfer(msg.sender, amount);
        require(success, "Collateral transfer failed");

        emit ClaimedWinnings(msg.sender, amount);
    }

    function splitAndSwap(
        uint256 collateralAmount,
        bool wantYes,
        uint256 amountOutMin,
        uint256 deadline
    ) external {
        require(!resolved, "Market already resolved");
        require(collateralAmount > 0, "Invalid collateralAmount");

        bool success = collateral.transferFrom(msg.sender, address(this), collateralAmount);
        require(success, "Collateral transfer failed");

        totalCollateral += collateralAmount;

        yesToken.mint(address(this), collateralAmount);
        noToken.mint(address(this), collateralAmount);

        address[] memory path = new address[](2);
        uint256 swapAmount = collateralAmount;

        if (wantYes) {
            path[0] = address(noToken);
            path[1] = address(yesToken);
        } else {
            path[0] = address(yesToken);
            path[1] = address(noToken);
        }

        IERC20(path[0]).approve(address(router), swapAmount);
        router.swapExactTokensForTokens(
            swapAmount,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        if (wantYes) {
            uint256 finalYesBal = yesToken.balanceOf(address(this));
            yesToken.transfer(msg.sender, finalYesBal);
        } else {
            uint256 finalNoBal = noToken.balanceOf(address(this));
            noToken.transfer(msg.sender, finalNoBal);
        }
    }
}
