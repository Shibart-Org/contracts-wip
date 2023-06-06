# To load the variables in the .env file
source .env

# To deploy and verify our contract
forge script script/sepolia.s.sol:SepoliaSystem --rpc-url $SEPOLIA_RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY --broadcast --verify -vvvv