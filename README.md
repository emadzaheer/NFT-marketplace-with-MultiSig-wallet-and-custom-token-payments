# NFT-marketplace-with-MultiSig-wallet-and-custom-token-payments
An ERC 721 based NFT market place which allows payments using a custom Marketplace token via a multi signature wallet 

## Process Flow

- deploy the MPtoken
- deploy multiSigWallet params: (MPtokenaddress, userAddresses[], min amount of votes or approvals)
- deploy the marketplace params: (MPtoken address, multiSigWalletaddress )

- mint MPtokens for addresses in MPtoken contract.
- approve limit for both multiSigWallet and Demarketplace contracts in the MPtoken contract.

- mint token in the marketplace
- list token for sale. (price should be > listing price);

- buy token in the marketplace. 
- check whether the erc20 balance was updated in the multisigwallet using getContractBalance() function. 
- feel free to withdraw acc to multi sig wallet rules. 
