# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build
test   :; forge test --rpc-url=${ETH_RPC_URL}
trace   :; forge test -vvv --rpc-url=${ETH_RPC_URL}
test-pre-creation  :; forge test --rpc-url=${ETH_RPC_URL} --fork-block-number=14255777
test-voting   :; forge test --rpc-url=${ETH_RPC_URL} --fork-block-number=14255779
test-queued   :; forge test -vvv --rpc-url=${ETH_RPC_URL} --fork-block-number=14275700