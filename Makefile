# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

################################################################################################
# Utils
################################################################################################

fmt:
	forge fmt

################################################################################################
# Foundry Dependencies
################################################################################################

remove:
	rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules

install:
	forge install foundry-rs/forge-std --no-commit
	forge install Transient-Labs/tl-creator-contracts@3.0.3 --no-commit
	forge install dmfxyz/murky --no-commit
	git add .
	git commit

update: remove install
	
################################################################################################
# Build
################################################################################################
clean:
	forge clean

build:
	forge build --evm-version paris --sizes

clean_build: clean build

docs: clean_build
	forge doc --build

################################################################################################
# Test
################################################################################################
default_test:
	forge test

gas_test:
	forge test --gas-report

coverage_test:
	forge coverage

fuzz_test:
	forge test --fuzz-runs 10000