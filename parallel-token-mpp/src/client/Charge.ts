import { Credential, Method } from 'mppx'
import { createWalletClient, http, type Hash, type Account, type Chain } from 'viem'
import * as Methods from '../Methods.js'

export function charge<const parameters extends charge.Parameters>(parameters: parameters) {
  const { parallelToken, account, chain, rpcUrl, tokenResolver } = parameters

  return Method.toClient(Methods.charge, {
    async createCredential({ challenge }): Promise<string> {
      const { request } = challenge

      const tokenId = await tokenResolver({
        amount: request.amount,
        currency: request.currency,
        owner: account.address,
      })

      const walletClient = createWalletClient({
        account,
        chain,
        transport: http(rpcUrl),
      })

      const hash = await walletClient.writeContract({
        address: parallelToken as Hash,
        abi: PARALLEL_TOKEN_ABI,
        functionName: 'push',
        args: [BigInt(tokenId), request.recipient as Hash],
      } as any)

      return Credential.serialize({
        challenge,
        payload: {
          tokenId,
          txHash: hash,
        },
      })
    },
  })
}

const PARALLEL_TOKEN_ABI = [
  {
    inputs: [
      { name: '_id', type: 'uint256' },
      { name: '_to', type: 'address' },
    ],
    name: 'push',
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const

export declare namespace charge {
  type Parameters = {
    parallelToken: string
    account: Account
    chain?: Chain | undefined
    rpcUrl: string
    tokenResolver: (options: {
      amount: string
      currency: string
      owner: string
    }) => Promise<string>
  }
}
