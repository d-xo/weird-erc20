solc = solc:0.6.12

all    :; dapp --use ${solc} build
test   :; dapp --use ${solc} test
clean  :; dapp clean
