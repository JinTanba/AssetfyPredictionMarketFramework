// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@assetfy/ARCSMarket.sol";
import "../src/AssetfyPredictionFactory.sol";
import "../src/AssetfyPredictionMarket.sol";

contract Oracle {
    address internal factory;
    bytes32 internal codeHash;
    constructor(address _marketFactory, bytes32 marketCodeHash) {
        factory = _marketFactory;
        codeHash = marketCodeHash;
    }

    function resolveMarket(
        address arcsMarketAddress,
        uint256 projectId
    ) external {
       AssetfyMarket.Project memory p = AssetfyMarket(arcsMarketAddress).getProject(projectId);
       require(block.timestamp >=p.maturityTime, "not maturityTime yet");
       bool isYes = p.totalRepaid >= p.targetAmount;
       AssetfyPrediction(computeAddress(arcsMarketAddress, projectId)).resolveMarket(isYes);
    }

    function computeAddress(
        address arcsMarketAddress,
        uint256 projectId
    ) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(arcsMarketAddress, projectId));
        bytes32 rawAddress = keccak256(
            abi.encodePacked(
                bytes1(0xFF),
                factory,
                salt,
                codeHash
            )
        );
        return address(uint160(uint256(rawAddress)));
    }
}