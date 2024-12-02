-include .env

deploy:;  forge script script/DeployDecentralizedAXUSD.s.sol  --rpc-url http://127.0.0.1:8545 --private-key $(ANVIL_PRIVATE_KEY)  --broadcast
compile:; forge compile