// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@assetfy/ARCSMarket.sol";
import "../src/interfaces/UniswapV2.sol";
import "../src/AssetfyPredictionMarket.sol";
import "../src/AssetfyPredictionMarketOracle.sol";


contract AssetfyPredictionMarketFactory {
    event MarketCreated(address indexed market);

    IUniswapV2Router02 public immutable router;
    IERC20 public immutable collateral;
    address public oracle;
    bytes public marketByteCode;

    constructor(address _collateral, address _router) {
        collateral = IERC20(_collateral);
        router = IUniswapV2Router02(_router);
        marketByteCode = type(AssetfyPrediction).creationCode;
        oracle = address(new Oracle(address(this), keccak256(marketByteCode)));
    }


    function deploy(
        address arcsMarketAddress,
        uint256 projectId,
        string memory yesName,
        string memory yesSymbol,
        string memory noName,
        string memory noSymbol
    ) external returns (address newMarket) {
        bytes32 salt = keccak256(abi.encodePacked(arcsMarketAddress, projectId));
        bytes memory initCode = marketByteCode;

        assembly {
            newMarket := create2(
                0,
                add(initCode, 0x20),
                mload(initCode),
                salt
            )
        }
        require(newMarket != address(0), "Create2: Failed on deploy");

        AssetfyPrediction(newMarket).initialize(
            address(collateral),
            address(router),
            oracle,
            yesName,
            yesSymbol,
            noName,
            noSymbol,
            arcsMarketAddress,
            projectId
        );

        emit MarketCreated(newMarket);
        return newMarket;
    }
}

