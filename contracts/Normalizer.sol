// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@chainlink/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./defs/NormalizationStrategy.sol";
import "./OwnablePausable.sol";

interface IUniswapV2Router {
    function getAmountsOut(
        uint amountIn,
        address[] memory path
    ) external view returns (uint[] memory amounts);
}

interface IERC20Metadata {
    function decimals() external view returns (uint8);
}

abstract contract Normalizer is OwnablePausable {
    event AssetDisabled(address indexed asset);
    event AssetEnabled(address indexed asset, address indexed feed);

    // for Uniswap V3
    uint24 private constant FEE = 3000;

    // map an asset to a feed that returns its conversion rate to normalized token
    mapping(address => address) public feeds;
    // enabled stablecoins like USDT, USDC, and BUSD that need no normalization
    mapping(address => bool) public stables;

    // for Uniswap strategies, the canonical stablecoin to normalize into
    // not used by price feeds
    address canonicalStable;

    // factory/router address for Uniswap strategies
    address uniswapEntrypoint;

    NormalizationStrategy internal immutable strategy;

    constructor(
        NormalizationStrategy strategy_,
        address canonicalStable_,
        address uniswapEntrypoint_
    ) {
        if (strategy_ != NormalizationStrategy.PriceFeed) {
            uniswapEntrypoint = uniswapEntrypoint_;
            canonicalStable = canonicalStable_;
        }
        strategy = strategy_;
    }

    //
    // - MUTATORS (ADMIN)
    //
    function controlAssetsWhitelisting(
        address[] memory tokens_,
        address[] memory feeds_
    ) external {
        _checkOwner();

        _controlAssetsWhitelisting(tokens_, feeds_);
    }

    function controlStables(
        address[] memory stables_,
        bool[] memory states_
    ) external {
        _checkOwner();

        _controlStables(stables_, states_);
    }

    //
    // - INTERNALS
    //
    function _controlAssetsWhitelisting(
        address[] memory assets_,
        address[] memory feeds_
    ) internal {
        uint256 numAssets = assets_.length;
        for (uint256 f = 0; f < numAssets; f++) {
            require(assets_[f] != address(0), "Zero Asset Address");
            feeds[assets_[f]] = feeds_[f];
            if (feeds_[f] == address(0)) {
                emit AssetDisabled(assets_[f]);
            } else {
                emit AssetEnabled(assets_[f], feeds_[f]);
            }
        }
    }

    function _controlStables(
        address[] memory assets_,
        bool[] memory states_
    ) internal {
        require(assets_.length == states_.length, "Mismatched Arrays");

        for (uint8 f = 0; f < assets_.length; f++) {
            require(assets_[f] != address(0), "Zero Asset Address");
            stables[assets_[f]] = states_[f];
            if (states_[f]) {
                emit AssetDisabled(assets_[f]);
            } else {
                emit AssetEnabled(assets_[f], assets_[f]);
            }
        }
    }

    function _requireTokenWhitelisted(address asset_) internal view {
        require(
            feeds[asset_] != address(0) || stables[asset_],
            "Invalid Payment Asset"
        );
    }

    function _normalize(
        address token,
        uint256 amount
    ) internal view returns (uint256) {
        if (token == address(0)) return 0;
        if (stables[token]) return amount;

        if (strategy == NormalizationStrategy.PriceFeed)
            return _priceFeedNormalize(token, amount);
        if (strategy == NormalizationStrategy.UniswapV3)
            return
                _adjustForDecimals(
                    token,
                    canonicalStable,
                    _uniV3Normalize(token, canonicalStable, amount)
                );

        // default to Uniswap V2
        return
            _adjustForDecimals(
                token,
                canonicalStable,
                _uniV2Normalize(token, canonicalStable, amount)
            );
    }

    function _priceFeedNormalize(
        address token,
        uint256 amount
    ) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(feeds[token]);

        (, int price, , , ) = priceFeed.latestRoundData();

        return (uint256(price) * amount) / (10 ** priceFeed.decimals());
    }

    function _uniV2Normalize(
        address token0,
        address token1,
        uint256 amount
    ) internal view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = token0;
        path[1] = token1;

        uint256[] memory amounts = IUniswapV2Router(uniswapEntrypoint)
            .getAmountsOut(amount, path);

        return amounts[amounts.length - 1];
    }

    function _uniV3Normalize(
        address token0,
        address token1,
        uint256 amount
    ) internal view returns (uint256 amountOut) {
        if (token0 == token1) return amount;

        address pool = IUniswapV3Factory(uniswapEntrypoint).getPool(
            token0,
            token1,
            FEE
        );

        uint32 secondsAgo = 1;
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(pool).observe(
            secondsAgos
        );

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

        int24 tick = int24(tickCumulativesDelta / int56(uint56(secondsAgo)));

        if (
            tickCumulativesDelta < 0 &&
            (tickCumulativesDelta % int56(uint56(secondsAgo)) != 0)
        ) {
            tick--;
        }

        amountOut = OracleLibrary.getQuoteAtTick(
            tick,
            uint128(amount),
            token0,
            token1
        );
    }

    function _adjustForDecimals(
        address token0,
        address token1,
        uint256 amount
    ) internal view returns (uint256) {
        uint8 estimatedTokenDecimals = IERC20Metadata(token0).decimals();
        uint8 normalizationTokenDecimals = IERC20Metadata(token1).decimals();
        uint8 decimalsDiff = (estimatedTokenDecimals >
            normalizationTokenDecimals)
            ? estimatedTokenDecimals - normalizationTokenDecimals
            : normalizationTokenDecimals - estimatedTokenDecimals;

        return amount * (10 ** decimalsDiff);
    }
}
