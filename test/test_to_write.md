In all case:
* TokenData struct must all be zero or all not zero

Mint
* ERC-20 must transfer to ParallelToken
* new Id must assigned to msg.sender
* amount must be the same
* ERC-20 token assigned to TokenData.underlyingERC20
* nonce is incremented

Burn
* ERC-20 must transfer to msg.sender
* every field clear to zero
* amount sent must be the same to TokenData.amount before clearing

MintMany
* Same as Mint, but expanded to all new token minted

BurnMany
* Same as Burn, but all token must have same TokenData.underlyingERC20