// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Governance.sol";
import "./DTtoken.sol";
import "./PRtoken.sol";
import "./interfaces/KeeperCompatibleInterface.sol";
import "./interfaces/IMyERC20.sol";
import "./interfaces/IMyERC721.sol";
import "./libraries/Strings.sol";

contract DTRUST is ERC1155, KeeperCompatibleInterface {
    using Strings for string;

    uint256 private constant PACK_INDEX =
        0x0000000000000000000000000000000000000000000000000000000000007FFF;

    enum TypeOfPayment {
        ERC20,
        ERC721,
        AnnualFee,
        None
    }

    struct ERC20TokenAsset {
        IMyERC20 erc20;
        uint256 erc20TokenId;
        uint256 erc20TokenAmount;
        uint256 erc20PaymentPerFrequency;
        uint256 paymentInterval;
        uint256 lockedUntil;
    }

    struct ERC721TokenAsset {
        IMyERC721 erc721;
        uint256 erc721TokenId;
        uint256 paymentInterval;
        uint256 lockedUntil;
    }

    struct Subscription {
        uint256 start;
        uint256 nextPayment;
        bool isTwoYear;
    }

    TypeOfPayment typeOfPayment;
    uint256 private constant _AnualFeeTotal = 0;
    uint256 public immutable basisPoint; // for 2 year
    uint256 public constant payAnnualFrequency = 730 days;
    uint256[] private erc20assetIds;
    uint256[] private erc721assetIds;
    address public immutable governanceAddress;
    address payable public immutable manager;
    address payable public immutable settlor;
    address payable public immutable trustee;
    address public immutable beneficiary;
    address public immutable promoter;
    string public dTrustUri;
    bool public immutable hasPromoter;
    Subscription private subscription;

    mapping(uint256 => bool) public existToken;
    mapping(uint256 => ERC20TokenAsset) public erc20TokenAssets;
    mapping(uint256 => ERC721TokenAsset) public erc721TokenAssets;

    event OrderBatch(
        address indexed _target,
        uint256[] indexed _ids,
        uint256[] indexed _amounts
    );
    event TransferBatch(
        bool indexed isERC20,
        address indexed from,
        address indexed to,
        uint256[] value
    );
    event Mint(address indexed sender, uint256 tokenId, uint256 amount);
    event AnnualPaymentSent(
        address from,
        uint256[] tokenIds,
        uint256 amount,
        uint256 total,
        uint256 date
    );
    event PaymentERC20Scheduled(
        uint256[] indexed erc20Assets,
        address recipient
    );
    event PaymentERC721Scheduled(
        uint256[] indexed erc721Assets,
        address recipient
    );
    event PaymentExecuted(
        address indexed scheduledTransaction,
        address recipient,
        uint256 value
    );
    event PayToBeneficiary(uint256[] ids, uint256[] amounts);

    modifier onlyManager() {
        require(
            msg.sender == manager ||
                msg.sender == settlor ||
                msg.sender == trustee ||
                msg.sender == address(this),
            "Error: The caller is not any of the defined managers (settlor and trustee)!"
        );
        _;
    }

    constructor(
        string memory _newURI,
        address payable _deployerAddress,
        address payable _settlor,
        address _beneficiary,
        address payable _trustee,
        address _governanceAddress,
        uint256 _basisPoint,
        bool _hasPromoter,
        address _promoter
    ) ERC1155(_newURI) {
        require(address(_deployerAddress) != address(0));
        require(address(_settlor) != address(0));
        require(address(_beneficiary) != address(0));
        require(address(_trustee) != address(0));

        dTrustUri = _newURI;
        manager = _deployerAddress;
        settlor = _settlor;
        beneficiary = _beneficiary;
        trustee = _trustee;

        subscription = Subscription(
            block.timestamp,
            block.timestamp + payAnnualFrequency,
            true
        );

        governanceAddress = _governanceAddress;
        basisPoint = _basisPoint;

        hasPromoter = _hasPromoter;
        promoter = _promoter;
    }

    function setURI(string memory _newURI) external onlyManager {
        _setURI(_newURI);
    }

    function getURI(string memory _uri, uint256 _id)
        public
        pure
        returns (string memory)
    {
        return toFullURI(_uri, _id);
    }

    function toFullURI(string memory _uri, uint256 _id)
        internal
        pure
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    _uri,
                    "/",
                    Strings.uint2str(_id & PACK_INDEX),
                    ".json"
                )
            );
    }

    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) external onlyManager {
        existToken[_id] = true;
        _mint(_to, _id, _quantity, _data);
    }

    function mintBatch(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) public onlyManager {
        for (uint256 i = 0; i < _ids.length; i++) {
            existToken[_ids[i]] = true;
        }
        _mintBatch(_to, _ids, _amounts, _data);
    }

    function fillOrderERC20Assets(
        IMyERC20[] memory _erc20Tokens,
        uint256[] memory _amounts,
        uint256[] memory _paymentPerFrequency,
        uint256[] memory _paymentIntervals,
        bytes calldata _data
    ) external onlyManager {
        uint256 _lengthOfErc20Token = _erc20Tokens.length;
        for (uint256 i = 0; i < _lengthOfErc20Token; i++) {
            uint256 id = uint256(uint160(address(_erc20Tokens[i])));
            erc20assetIds.push(id);

            ERC20TokenAsset memory newerc20 = ERC20TokenAsset(
                _erc20Tokens[i],
                id,
                _amounts[i],
                _paymentPerFrequency[i],
                _paymentIntervals[i],
                block.timestamp + _paymentIntervals[i]
            );
            erc20TokenAssets[id] = newerc20;
        }
        mintBatch(address(this), erc20assetIds, _amounts, _data);
        transferERC20(true, erc20assetIds, _amounts);
        emit OrderBatch(manager, erc20assetIds, _amounts);
    }

    function _tokenHash(IMyERC721 erc721token)
        internal
        virtual
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(erc721token)));
    }

    function fillOrderERC721Assets(
        IMyERC721[] calldata _erc721Tokens,
        bytes calldata _data,
        uint256[] memory _paymentPerFrequency
    ) external onlyManager {
        uint256 lengthOfErc721Tokens = _erc721Tokens.length;
        uint256[] memory amounts = new uint256[](lengthOfErc721Tokens);
        for (uint256 i = 0; i < lengthOfErc721Tokens; i++) {
            uint256 _erc1155TokenId = _tokenHash(_erc721Tokens[i]);
            erc721assetIds.push(_erc1155TokenId);
            ERC721TokenAsset memory newerc721 = ERC721TokenAsset(
                _erc721Tokens[i],
                _erc1155TokenId,
                _paymentPerFrequency[i],
                block.timestamp + _paymentPerFrequency[i]
            );
            erc721TokenAssets[_erc1155TokenId] = newerc721;
            amounts[i] = 1;
        }

        mintBatch(address(this), erc721assetIds, amounts, _data);
        transferERC721(true, erc721assetIds, amounts);
        emit OrderBatch(manager, erc721assetIds, amounts);
    }

    function getTargetDeposit(bool isERC20Asset, uint256 _tokenid)
        external
        view
        onlyManager
        returns (uint256)
    {
        if (isERC20Asset) {
            return erc20TokenAssets[_tokenid].erc20TokenAmount;
        } else {
            if (erc721TokenAssets[_tokenid].erc721TokenId != 0) {
                return 1;
            } else {
                return 0;
            }
        }
    }

    function schedulePaymentERC20Assets() internal {
        uint256 countOfToken = 0;
        uint256 lengthOfErc20Assets = erc20assetIds.length;
        uint256[] memory erc20TokenIds = new uint256[](lengthOfErc20Assets);
        uint256[] memory amountsOfPayment = new uint256[](lengthOfErc20Assets);

        for (uint256 i = 0; i < lengthOfErc20Assets; i++) {
            ERC20TokenAsset storage currentAsset = erc20TokenAssets[
                erc20assetIds[i]
            ];
            if (
                currentAsset.erc20TokenId == 0 ||
                block.number >= currentAsset.lockedUntil
            ) {
                continue;
            }

            uint256 erc20PaymentPerFrequency = currentAsset
                .erc20PaymentPerFrequency;

            if (erc20PaymentPerFrequency > currentAsset.erc20TokenAmount) {
                erc20TokenIds[countOfToken] = erc20assetIds[i];
                amountsOfPayment[countOfToken] = currentAsset.erc20TokenAmount;

                currentAsset.erc20TokenId = 0;
                currentAsset.erc20TokenAmount = 0;

                countOfToken++;
                continue;
            }

            currentAsset.erc20TokenAmount -= erc20PaymentPerFrequency;
            currentAsset.lockedUntil =
                block.timestamp +
                currentAsset.paymentInterval;

            erc20TokenIds[countOfToken] = erc20assetIds[i];
            amountsOfPayment[countOfToken] = erc20PaymentPerFrequency;

            countOfToken++;
        }
        require(countOfToken > 0, "No assets");

        _burnBatch(msg.sender, erc20TokenIds, amountsOfPayment);
        transferERC20(false, erc20TokenIds, amountsOfPayment);
        emit PayToBeneficiary(erc20TokenIds, amountsOfPayment);
    }

    function schedulePaymentERC721Assets() internal {
        uint256 countOfToken = 0;
        uint256 lengthOfErc721Assets = erc721assetIds.length;
        uint256[] memory erc721tokenIds = new uint256[](lengthOfErc721Assets);
        uint256[] memory amountsOfPayment = new uint256[](lengthOfErc721Assets);

        for (uint256 i = 0; i < lengthOfErc721Assets; i++) {
            ERC721TokenAsset storage currentAsset = erc721TokenAssets[
                erc721assetIds[i]
            ];
            if (
                currentAsset.erc721TokenId == 0 ||
                block.number >= currentAsset.lockedUntil
            ) {
                continue;
            }

            currentAsset.erc721TokenId == 0;

            erc721tokenIds[countOfToken] = erc721assetIds[i];
            amountsOfPayment[countOfToken] = 1;

            countOfToken++;
        }
        require(countOfToken > 0, "No assets");
        _burnBatch(msg.sender, erc721tokenIds, amountsOfPayment);
        transferERC721(false, erc721tokenIds, amountsOfPayment);
        emit PayToBeneficiary(erc721tokenIds, amountsOfPayment);
    }

    function transferERC20(
        bool _isDepositFunction,
        uint256[] memory _erc20TokenIds,
        uint256[] memory _amounts
    ) internal {
        uint256 lengthOfErc20Assets = _erc20TokenIds.length;
        if (_isDepositFunction) {
            for (uint256 i = 0; i < lengthOfErc20Assets; i++) {
                ERC20TokenAsset storage currentAsset = erc20TokenAssets[
                    _erc20TokenIds[i]
                ];
                bool success = currentAsset.erc20.transferFrom(
                    manager,
                    address(this),
                    _amounts[i]
                );
                if (!success) {
                    currentAsset.erc20TokenAmount = _amounts[i];
                }
            }
            emit TransferBatch(true, manager, address(this), _amounts);
        } else {
            // withdraw function
            for (uint256 i = 0; i < lengthOfErc20Assets; i++) {
                ERC20TokenAsset storage currentAsset = erc20TokenAssets[
                    _erc20TokenIds[i]
                ];
                bool success = currentAsset.erc20.transfer(
                    beneficiary,
                    _amounts[i]
                );
                if (!success) {
                    currentAsset.erc20TokenAmount = _amounts[i];
                }
            }
            emit TransferBatch(true, address(this), beneficiary, _amounts);
        }
    }

    function transferERC721(
        bool _isDepositFunction,
        uint256[] memory _erc721assetIds,
        uint256[] memory _amounts
    ) internal {
        uint256 lengthOfErc721Assets = _erc721assetIds.length;
        address from;
        address to;
        if (_isDepositFunction) {
            from = manager;
            to = address(this);
        } else {
            // widthdraw function
            from = address(this);
            to = beneficiary;
        }
        for (uint256 i = 0; i < lengthOfErc721Assets; i++) {
            ERC721TokenAsset storage currentAsset = erc721TokenAssets[
                _erc721assetIds[i]
            ];
            currentAsset.erc721.transferFrom(from, to, _amounts[i]);
        }
        emit TransferBatch(false, from, to, _amounts);
    }

    function paySemiAnnualFee() internal {
        require(subscription.isTwoYear);
        require(block.timestamp >= subscription.nextPayment, "not due yet");
        uint256 semiAnnualFee = 0;
        DTtoken dttoken;
        PRtoken prtoken;
        address target;

        uint256 countOfToken = 0;
        uint256 lengthOfErc20Assets = erc20assetIds.length;
        uint256[] memory tokenAmounts = new uint256[](lengthOfErc20Assets);
        uint256[] memory erc20TokenIds = new uint256[](lengthOfErc20Assets);

        for (uint256 i = 0; i < lengthOfErc20Assets; i++) {
            ERC20TokenAsset memory currentAsset = erc20TokenAssets[
                erc20assetIds[i]
            ];
            if (currentAsset.erc20TokenId == 0) {
                continue;
            }
            uint256 fee = currentAsset.erc20TokenAmount * (basisPoint / 100);

            if (fee > currentAsset.erc20TokenAmount) {
                erc20TokenIds[countOfToken] = erc20assetIds[i];
                tokenAmounts[countOfToken] = currentAsset.erc20TokenAmount;

                currentAsset.erc20TokenId = 0;
                currentAsset.erc20TokenAmount = 0;

                erc20TokenAssets[erc20assetIds[i]] = currentAsset;
                countOfToken++;
                continue;
            }

            tokenAmounts[countOfToken] = fee;
            erc20TokenIds[countOfToken] = erc20assetIds[i];

            currentAsset.erc20TokenAmount -= fee;
            semiAnnualFee += fee;
            erc20TokenAssets[erc20assetIds[i]] = currentAsset;
            countOfToken++;
        }

        if (hasPromoter) {
            target = promoter;
            prtoken.mint(promoter, semiAnnualFee, "");
        } else {
            target = governanceAddress;
            dttoken.mint(governanceAddress, semiAnnualFee);
        }
        _burnBatch(address(this), erc20TokenIds, tokenAmounts);
        transferERC20(false, erc20TokenIds, tokenAmounts);
        
        Governance governance;
        governance.splitAnnualFee(semiAnnualFee);

        emit AnnualPaymentSent(
            target,
            erc20TokenIds,
            semiAnnualFee,
            _AnualFeeTotal,
            block.timestamp
        );

        subscription.nextPayment += payAnnualFrequency;
        subscription.isTwoYear = false;
    }

    function checkUpkeep(bytes calldata checkData)
        external
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 lengthOfErc20Assets = erc20assetIds.length;
        uint256 lengthOfErc721Assets = erc721assetIds.length;
        upkeepNeeded = false;

        if (block.timestamp <= subscription.nextPayment) {
            upkeepNeeded = true;
            typeOfPayment = TypeOfPayment.AnnualFee;
        }

        if (!upkeepNeeded) {
            for (uint256 i = 0; i < lengthOfErc20Assets; i++) {
                ERC20TokenAsset storage currentERC20Asset = erc20TokenAssets[
                    erc20assetIds[i]
                ];

                if (block.timestamp <= currentERC20Asset.lockedUntil) {
                    upkeepNeeded = true;
                    typeOfPayment = TypeOfPayment.ERC20;
                    break;
                }
            }
        }
        if (!upkeepNeeded) {
            for (uint256 i = 0; i < lengthOfErc721Assets; i++) {
                ERC721TokenAsset storage currentERC721Asset = erc721TokenAssets[
                    erc721assetIds[i]
                ];

                if (block.timestamp <= currentERC721Asset.lockedUntil) {
                    upkeepNeeded = true;
                    typeOfPayment = TypeOfPayment.ERC721;
                    break;
                }
            }
        }

        typeOfPayment = TypeOfPayment.None;
    }

    function performUpkeep(bytes calldata performData) external override {
        if (typeOfPayment == TypeOfPayment.ERC20) {
            schedulePaymentERC20Assets();
        } else if (typeOfPayment == TypeOfPayment.ERC721) {
            schedulePaymentERC721Assets();
        } else if (typeOfPayment == TypeOfPayment.AnnualFee) {
            paySemiAnnualFee();
        }
    }
}
