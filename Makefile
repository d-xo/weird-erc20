build:
	export DAPP_SOLC=solc-0.6.12; dapp build
	export DAPP_SOLC=solc-0.7.6; dapp build
	export DAPP_SOLC=solc-0.8.6; dapp build
test:
	DAPP_SOLC=solc-0.8.6; dapp test
