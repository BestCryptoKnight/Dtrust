// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DTRUST.sol";
import "./ControlKey.sol";

contract DTRUSTFactory {
    DTRUST[] public deployedDTRUSTs;
    uint256 public basisPoint;
    address public governanceAddress;
    bytes32[] questions;

    mapping(DTRUST => bool) isDeployed;

    event CreateDTRUST(DTRUST createdDtrust, string indexed newuri);
    event UpdateBasisPoint(uint256 basispoint);
    event UpdateQuestion(bytes32[] allQuestions);

    constructor(address _governanceAddress) {
        governanceAddress = _governanceAddress;
        basisPoint = 1;
    }

    function getQuestions() external view returns (bytes32[] memory) {
        return questions;
    }

    function createDTRUST(
        string memory _newuri,
        address _settlor,
        address _beneficiary,
        address _trustee,
        bool _hasPromoter,
        address promoter
    ) external {
        DTRUST newDTRUST = new DTRUST(
            _newuri,
            payable(msg.sender),
            payable(_settlor),
            _beneficiary,
            payable(_trustee),
            governanceAddress,
            basisPoint,
            _hasPromoter,
            promoter
        );
        deployedDTRUSTs.push(newDTRUST);
        isDeployed[newDTRUST] = true;

        emit CreateDTRUST(newDTRUST, _newuri);
    }

    function getAllDeployedDTRUSTs() external view returns (DTRUST[] memory) {
        return deployedDTRUSTs;
    }

    function updateBasisPoint(uint256 _basisPoint) external {
        basisPoint = _basisPoint;

        emit UpdateBasisPoint(basisPoint);
    }

    function updateQuestion(bytes32 _content) external {
        questions.push(_content);

        emit UpdateQuestion(questions);
    }
}
