// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./ClaimTracker.sol";
import "./Normalizer.sol";
import "./interfaces/IGenerationToken.sol";
import "./interfaces/IPulseRaiser.sol";

contract PulseRaiser is IPulseRaiser, Normalizer, ClaimTracker {
    // guard against ERC20 tokens that do now follow the ERC20, such as USDT
    using SafeERC20 for IERC20;
    // use sendValue to transfer native currency
    using Address for address payable;

    address public wallet;

    // 1111111111, see pppval
    uint256 private constant LOWEST_10_BITS_MASK = 1023;

    // DO NOT MODIFY the DAYS constant
    uint8 private constant DAYS = 20;

    //
    // - STORAGE
    //

    // The amount of points allocated to each day's normalized price
    uint32 public immutable points;
    // The sale starts at this time
    uint32 public launchAt;

    // Instead of storing 20 uint256 price values for 20 days, which takes 20 SSTOREs
    // use a single slot to encode reduced prices for each day. A day's price is contained
    // in a 10-bit span, 20x10 == 200 bits, which fits into a uint256.
    uint256 public encodedpp = _encodeInitialPriceBases();

    // store point balances of all the participating accounts
    mapping(address => uint256) public pointsGained;

    // points allocated here
    uint256 public pointsLocal;
    uint256 public raiseLocal;

    // generation token
    IGenerationToken public token;
    uint256 public tokenPerPoint;

    bool public claimsEnabled;
    bytes32 public merkleRoot;

    address public immutable wrappedNative;

    constructor(
        address token_,
        address wrappedNative_,
        address canonicalStable_,
        address uniswapFactory_,
        address wallet_,
        uint32 points_,
        address[] memory stables_,
        address[] memory assets_,
        address[] memory feeds_,
        NormalizationStrategy strategy_
    ) Normalizer(strategy_, canonicalStable_, uniswapFactory_) {
        // NOTE: ignore token_ being address(0); this would indicate
        // a collatable deployment that doesn't need a token
        require(wrappedNative_ != address(0), "Zero Wrapped Native Token");
        if (strategy_ != NormalizationStrategy.PriceFeed) {
            require(
                canonicalStable_ != address(0),
                "Zero Canonical Stable Addr"
            );
            require(uniswapFactory_ != address(0), "Zero Uniswap Factory Addr");
        }

        require(wallet_ != address(0), "Zero Wallet Addr");
        require(points_ > 0, "Zero Points");

        points = points_;

        wallet = wallet_;

        wrappedNative = wrappedNative_;

        if (token_ != address(0)) {
            token = IGenerationToken(token_);
        }

        if (assets_.length > 0) {
            _controlAssetsWhitelisting(assets_, feeds_);
        }

        if (stables_.length > 0) {
            bool[] memory states_ = new bool[](stables_.length);
            for (uint8 t = 0; t < stables_.length; t++) {
                states_[t] = true;
            }
            _controlStables(stables_, states_);
        }
    }

    function estimate(
        address token_,
        uint256 amount
    ) external view returns (uint256) {
        _requireSaleInProgress();
        _requireTokenWhitelisted(token_);

        uint256 numerator_ = points * _normalize(token_, amount);

        uint256 currentPrice_ = _currentPrice();

        return numerator_ / currentPrice_;
    }

    function normalize(
        address token_,
        uint256 amount_
    ) external view returns (uint256) {
        return _normalize(token_, amount_);
    }

    function currentPrice() external view returns (uint256) {
        _requireSaleInProgress();
        return _currentPrice();
    }

    function nextPrice() external view returns (uint256) {
        return _nextPrice();
    }

    //
    // - MUTATORS
    //
    function contribute(
        address token_,
        uint256 tokenAmount,
        address referral
    ) external payable {
        _requireNotPaused();
        _requireSaleInProgress();
        _requireEOA();

        address account = msg.sender;
        uint256 normalizedAmount;

        if (token_ != address(0) && tokenAmount > 0) {
            _requireTokenWhitelisted(token_);
            normalizedAmount += _normalize(token_, tokenAmount);
        }

        if (msg.value > 0) {
            normalizedAmount += _normalize(wrappedNative, msg.value);
        }

        uint256 pointAmount = (points * normalizedAmount) / _currentPrice();

        require(pointAmount > 0, "Insufficient Contribution");

        pointsGained[account] += pointAmount;

        pointsLocal += pointAmount;
        raiseLocal += normalizedAmount;

        emit PointsGained(account, pointAmount);

        if (referral != address(0)) {
            emit Referral(referral, normalizedAmount);
        }

        if (token_ != address(0)) {
            IERC20(token_).safeTransferFrom(account, wallet, tokenAmount);
        }

        if (msg.value > 0) {
            payable(wallet).sendValue(msg.value);
        }
    }

    function claim(
        uint256 index_,
        uint256 points_,
        bytes32[] calldata proof_
    ) external {
        _requireNotPaused();
        _requireClaimsEnabled();
        address account = msg.sender;
        uint256 pointsTotal;

        // if there's a points record, delete and add token based on points held
        if (pointsGained[account] > 0) {
            pointsTotal += pointsGained[account];
            delete pointsGained[account];
        }

        // if a valid proof is supplied, mark used and add token based on points held
        if (proof_.length > 0) {
            require(_attempSetClaimed(index_), "Proof Already Used");
            bytes32 node = keccak256(
                abi.encodePacked(index_, account, points_)
            );

            require(
                MerkleProof.verifyCalldata(proof_, merkleRoot, node),
                "Invalid Merkle Proof"
            );

            pointsTotal += points_;
        }

        if (pointsTotal > 0) {
            token.distribute(account, pointsTotal * tokenPerPoint);
        }
    }

    //
    // - MUTATORS (ADMIN)
    //
    function launch(uint32 at) external {
        _checkOwner();
        if (at == 0) {
            launchAt = uint32(block.timestamp);
        } else {
            require(at > block.timestamp, "Future Timestamp Expected");
            launchAt = at;
        }
        emit LaunchTimeSet(launchAt);
    }

    function setRaiseWallet(address wallet_) external {
        _checkOwner();
        require(wallet_ != address(0), "Zero Wallet Addr");

        emit RaiseWalletUpdated(wallet, wallet_);
        wallet = wallet_;
    }

    function modifyPriceBase(uint8 dayIndex_, uint16 priceBase_) external {
        _checkOwner();
        _requireDayInRange(dayIndex_);
        _requireValidPriceBase(priceBase_);
        uint16[] memory priceBases = _splitPriceBases();

        priceBases[dayIndex_] = priceBase_;

        encodedpp = _encodePriceBasesMemory(priceBases);

        emit PriceBaseModified(dayIndex_, priceBase_);
    }

    function modifyPriceBases(uint16[] calldata priceBases) external {
        _checkOwner();
        require(priceBases.length == DAYS, "Invalid Bases Count");
        for (uint8 i = 0; i < DAYS; i++) {
            _requireValidPriceBase(priceBases[i]);
        }
        encodedpp = _encodePriceBases(priceBases);

        emit PriceBasesBatchModified();
    }

    function collate(
        bytes32 merkleRoot_,
        uint256 pointsOtherNetworks
    ) external {
        _checkOwner();
        require(address(token) != address(0), "Not the Primary Contract");
        require(
            block.timestamp >= launchAt + DAYS * 1 days,
            "Wait for Sale to Complete"
        );
        require(!claimsEnabled, "Distribution Locked");
        uint256 pointsTotal = pointsLocal + pointsOtherNetworks;

        uint256 distributionSupply = token.distributionSupply();

        tokenPerPoint = distributionSupply / pointsTotal;

        merkleRoot = merkleRoot_;
        emit TotalPointsAllocated(pointsTotal, tokenPerPoint);
    }

    function distribute() external {
        _checkOwner();
        require(tokenPerPoint > 0, "Collate First");
        claimsEnabled = true;
        emit ClaimsEnabled();
    }

    //
    // - INTERNALS
    //
    function _currentPrice() internal view returns (uint256) {
        // if not yet launched will revert, otherwise will result
        // in days 0..N, where the largest legal N is 19, pppval
        // will revert starting with dayIndex == 20
        uint8 dayIndex = uint8((block.timestamp - launchAt) / 1 days);

        return _pppval(dayIndex);
    }

    function _nextPrice() internal view returns (uint256) {
        uint256 tmrwIndex = ((block.timestamp - launchAt) / 1 days) + 1;

        if (tmrwIndex > 19) return 0;

        return _pppval(uint8(tmrwIndex));
    }

    function _pppval(uint8 dayIndex) internal view returns (uint256) {
        _requireDayInRange(dayIndex);
        return ((encodedpp >> (dayIndex * 10)) & LOWEST_10_BITS_MASK) * 1e16;
    }

    function _requireValidPriceBase(uint16 pb) internal pure {
        require(pb <= 1023, "Price Base Exceeds 10 Bits");
        require(pb > 0, "Zero Price Base");
    }

    function _requireClaimsEnabled() internal view {
        require(claimsEnabled, "Wait for Claims");
    }

    function _encodePriceBases(
        uint16[] calldata bases_
    ) private pure returns (uint256 encode) {
        for (uint8 d = 0; d < DAYS; d++) {
            encode = encode | (uint256(bases_[d]) << (d * 10));
        }
    }

    function _encodePriceBasesMemory(
        uint16[] memory bases_
    ) private pure returns (uint256 encode) {
        for (uint8 d = 0; d < DAYS; d++) {
            encode = encode | (uint256(bases_[d]) << (d * 10));
        }
    }

    function _splitPriceBases() private view returns (uint16[] memory) {
        uint16[] memory split = new uint16[](DAYS);
        for (uint8 dayIndex = 0; dayIndex < DAYS; dayIndex++) {
            split[dayIndex] = uint16(
                (encodedpp >> (dayIndex * 10)) & LOWEST_10_BITS_MASK
            );
        }
        return split;
    }

    // used one time during deployment
    function _encodeInitialPriceBases() private pure returns (uint256) {
        // - use 200 lowest bits of a uint256 to encode
        //   the normalized price of points in USD multiplied by 100
        // - values need to be multiplied by e16 to get wei equivalents
        uint256 encode = 493 << 10;
        encode |= 411;
        encode = encode << 10;
        encode |= 343;
        encode = encode << 10;
        encode |= 286;
        encode = encode << 10;
        encode |= 260;
        encode = encode << 10;
        encode |= 236;
        encode = encode << 10;
        encode |= 215;
        encode = encode << 10;
        encode |= 195;
        encode = encode << 10;
        encode |= 177;
        encode = encode << 10;
        encode |= 161;
        encode = encode << 10;
        encode |= 146;
        encode = encode << 10;
        encode |= 133;
        encode = encode << 10;
        encode |= 121;
        encode = encode << 10;
        encode |= 110;
        encode = encode << 10;
        encode |= 105;
        encode = encode << 10;
        encode |= 100;
        encode = encode << 10;
        encode |= 100;
        encode = encode << 10;
        encode |= 100;
        encode = encode << 10;
        encode |= 100;
        encode = encode << 10;
        encode |= 100;

        return encode;
    }

    function _requireSaleInProgress() internal view {
        require(launchAt > 0, "Sale Time Not Set");
        require(block.timestamp >= launchAt, "Sale Not In Progress");
        require(block.timestamp <= launchAt + DAYS * 1 days, "Sale Ended");
    }

    function _requireEOA() internal view {
        require(msg.sender == tx.origin, "Caller Not an EOA");
    }

    function _requireDayInRange(uint8 dayIndex) internal pure {
        require(dayIndex < DAYS, "Expected a 0-19 Day Index");
    }
}
