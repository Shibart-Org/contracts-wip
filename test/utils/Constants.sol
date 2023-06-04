// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

abstract contract Constants {
    uint32 internal constant POINTS = 10000;
    uint256 internal constant SHIBART_FULL_SUPPLY = 1_000_000_000 ether;

    //#region Ethereum Mainnet

    // Ethereum Mainnet USDT
    // https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7
    address internal constant ETH_MAINNET_USDT =    0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // Ethereum Mainnet USDC
    // https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    address internal constant ETH_MAINNET_USDC =    0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Ethereum Mainnet WETH
    // https://etherscan.io/address/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    address internal constant ETH_MAINNET_WETH =    0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Ethereum Mainnet WBTC
    // https://etherscan.io/address/0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599
    address internal constant ETH_MAINNET_WBTC =    0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    // Ethereum Mainnet ETH/USD Price Feed
    // https://docs.chain.link/data-feeds/price-feeds/addresses#Ethereum%20Mainnet
    address internal constant ETH_MAINNET_FEED_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    // Ethereum Mainnet BTC/USD Price Feed
    // https://docs.chain.link/data-feeds/price-feeds/addresses#Ethereum%20Mainnet
    address internal constant ETH_MAINNET_FEED_BTC_USD = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;

    //#endregion

    function ethereumMainnetRaiserTokens() public pure returns (address[] memory) {
        address[] memory tokens_ = new address[](4);
        tokens_[0] = ETH_MAINNET_USDT;
        tokens_[1] = ETH_MAINNET_USDC;
        tokens_[2] = ETH_MAINNET_WETH;
        tokens_[3] = ETH_MAINNET_WBTC;
        return tokens_;
    }


    //#region Arbitrum Mainnet

    // Arbitrum Mainnet USDT
    // https://arbiscan.io/address/0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9
    address internal constant ARB_MAINNET_USDT =   0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    // Arbitrum Mainnet USDC.e
    // https://arbiscan.io/address/0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8
    address internal constant ARB_MAINNET_USDC =   0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

    // Arbitrum Mainnet WETH
    // https://arbiscan.io/address/0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
    address internal constant ARB_MAINNET_WETH =   0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    // Arbitrum Mainnet WBTC
    // https://arbiscan.io/address/0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f
    address internal constant ARB_MAINNET_WBTC =   0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    // Arbitrum Mainnet ETH/USD Price Feed
    // https://docs.chain.link/data-feeds/price-feeds/addresses?network=arbitrum#Arbitrum%20Mainnet
    address internal constant ARB_MAINNET_FEED_ETH_USD = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    // Arbitrum Mainnet BTC/USD Price Feed
    // https://docs.chain.link/data-feeds/price-feeds/addresses?network=arbitrum#Arbitrum%20Mainnet
    address internal constant ARB_MAINNET_FEED_BTC_USD = 0x6ce185860a4963106506C203335A2910413708e9;
    //#endregion

    function arbitrumMainnetRaiserTokens() public pure returns (address[] memory) {
        address[] memory tokens_ = new address[](4);
        tokens_[0] = ARB_MAINNET_USDT;
        tokens_[1] = ARB_MAINNET_USDC;
        tokens_[2] = ARB_MAINNET_WETH;
        tokens_[3] = ARB_MAINNET_WBTC;
        return tokens_;
    }

    //#region BSC Mainnet
    // BSC Mainnet USDT
    // https://bscscan.com/token/0x55d398326f99059ff775485246999027b3197955
    address internal constant BSC_MAINNET_USDT =   0x55d398326f99059fF775485246999027B3197955;

    // BSC Mainnet USDC
    // https://bscscan.com/address/0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d
    address internal constant BSC_MAINNET_USDC =   0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    // BSC Mainnet BUSD
    // https://bscscan.com/token/0xe9e7cea3dedca5984780bafc599bd69add087d56
    address internal constant BSC_MAINNET_BUSD =   0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    // BSC Mainnet WBNB
    // https://bscscan.com/token/0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
    address internal constant BSC_MAINNET_WBNB =   0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    // BSC Mainnet WBTCB
    // https://bscscan.com/token/0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c
    address internal constant BSC_MAINNET_BTCB =   0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;


    // BSC Mainnet BNB/USD Price Feed
    // https://docs.chain.link/data-feeds/price-feeds/addresses?network=bnb-chain#BNB%20Chain%20Mainnet
    address internal constant BSC_MAINNET_FEED_BNB_USD = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;

    // BSC Mainnet BTC/USD Price Feed
    // https://docs.chain.link/data-feeds/price-feeds/addresses?network=bnb-chain#BNB%20Chain%20Mainnet
    address internal constant BSC_MAINNET_FEED_BTC_USD = 0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf;

    //#endregion

    function BSCMainnetRaiserTokens() public pure returns (address[] memory) {
        address[] memory tokens_ = new address[](5);
        tokens_[0] = BSC_MAINNET_USDT;
        tokens_[1] = BSC_MAINNET_USDC;
        tokens_[2] = BSC_MAINNET_BUSD;
        tokens_[3] = BSC_MAINNET_WBNB;
        tokens_[4] = BSC_MAINNET_BTCB;
        return tokens_;
    }

    mapping(uint256 => mapping(address => string)) internal tokenLabels;

    constructor() {
        uint256 arbFork = 0;
        uint256 bscFork = 1;
        uint256 ethFork = 2;

        _label(ethFork, ETH_MAINNET_WETH, "Ethereum WETH");
        _label(ethFork, ETH_MAINNET_WBTC, "Ethereum WBTC");
        _label(ethFork, ETH_MAINNET_USDT, "Ethereum USDT");
        _label(ethFork, ETH_MAINNET_USDC, "Ethereum USDC");

        _label(arbFork, ARB_MAINNET_WETH, "Arbitrum WETH");
        _label(arbFork, ARB_MAINNET_WBTC, "Arbitrum WBTC");
        _label(arbFork, ARB_MAINNET_USDT, "Arbitrum USDT");
        _label(arbFork, ARB_MAINNET_USDC, "Arbitrum USDC");

        _label(bscFork, BSC_MAINNET_WBNB, "BSC WBNB");
        _label(bscFork, BSC_MAINNET_BTCB, "BSC BTCB");
        _label(bscFork, BSC_MAINNET_BUSD, "BSC BUSD");
        _label(bscFork, BSC_MAINNET_USDT, "BSC USDT");
        _label(bscFork, BSC_MAINNET_USDC, "BSC USDC");
    }

    function _label(
        uint256 forkId,
        address token,
        string memory label
    ) internal {
        tokenLabels[forkId][token] = label;
    }

    function getLabel(
        uint256 forkId,
        address token
    ) internal view returns (string memory) {
        return tokenLabels[forkId][token];
    }
}