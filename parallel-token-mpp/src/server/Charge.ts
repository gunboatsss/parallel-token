import { Credential, Errors, Method } from 'mppx'
import type { PublicClient, Hash, Chain } from 'viem'
import * as Methods from '../Methods.js'

const TRANSFER_EVENT_SIGNATURE =
  '0x4ad7c68d87d7d32d1c1e1c1008c0e5a7c2d8f7c5e9b4a3c2d1e0f9a8b7c6d5e'

interface ParallelTokenTransfer {
  from: string
  to: string
  id: string
  memo: string
}

export function charge<const parameters extends charge.Parameters>(parameters: parameters) {
  const { amount, currency, recipient, parallelToken, rpcUrl, minConfirmations = 1 } = parameters

  type Defaults = {
    amount?: string
    currency?: string
    recipient?: string
    parallelToken?: string
  }
  return Method.toServer<typeof Methods.charge, Defaults>(Methods.charge, {
    defaults: {
      amount,
      currency,
      recipient,
      parallelToken,
    } as Defaults,

    async verify({ credential }) {
      const { challenge } = credential
      const { request } = challenge

      const parsed = Methods.charge.schema.credential.payload.safeParse(credential.payload)
      if (!parsed.success) {
        throw new Error('Invalid credential payload: missing tokenId or txHash')
      }
      const { tokenId, txHash } = parsed.data

      const publicClient: PublicClient = {
        request: async ({ method, params }) => {
          const response = await fetch(rpcUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              jsonrpc: '2.0',
              id: 1,
              method,
              params,
            }),
          })
          const result = await response.json() as { result: unknown }
          return result.result
        },
      } as PublicClient

      const receipt = await publicClient.getTransactionReceipt({ hash: txHash as Hash }) as any

      if (!receipt) {
        throw new Errors.VerificationFailedError({ reason: 'Transaction not found' })
      }

      if ((receipt.confirmations ?? 0) < minConfirmations) {
        throw new Errors.VerificationFailedError({
          reason: `Insufficient confirmations: ${receipt.confirmations ?? 0}/${minConfirmations}`,
        })
      }

      const transferEvent = receipt.logs.find((log: any) => {
        return log.topics[0] === TRANSFER_EVENT_SIGNATURE
      })

      if (!transferEvent) {
        throw new Errors.VerificationFailedError({ reason: 'No Transfer event found in transaction' })
      }

      const decodedTransfer = decodeTransferEvent(transferEvent)
      if (!decodedTransfer) {
        throw new Errors.VerificationFailedError({ reason: 'Failed to decode Transfer event' })
      }

      if (decodedTransfer.to.toLowerCase() !== request.recipient.toLowerCase()) {
        throw new Errors.VerificationFailedError({
          reason: `Recipient mismatch: expected ${request.recipient}, got ${decodedTransfer.to}`,
        })
      }

      if (decodedTransfer.id !== tokenId) {
        throw new Errors.VerificationFailedError({
          reason: `Token ID mismatch: expected ${tokenId}, got ${decodedTransfer.id}`,
        })
      }

      const tokenData = await fetchTokenData(parallelToken!, tokenId, publicClient)
      if (!tokenData) {
        throw new Errors.VerificationFailedError({ reason: 'Failed to fetch token data' })
      }

      if (tokenData.underlyingERC20!.toLowerCase() !== request.currency.toLowerCase()) {
        throw new Errors.VerificationFailedError({
          reason: `Currency mismatch: expected ${request.currency}, got ${tokenData.underlyingERC20}`,
        })
      }

      if (BigInt(tokenData.amount) < BigInt(request.amount)) {
        throw new Errors.VerificationFailedError({
          reason: `Insufficient amount: required ${request.amount}, got ${tokenData.amount}`,
        })
      }

      return {
        method: 'parallelToken',
        status: 'success',
        timestamp: new Date().toISOString(),
        reference: txHash,
      } as const
    },
  })
}

function decodeTransferEvent(log: { topics: string[]; data: string }): ParallelTokenTransfer | null {
  try {
    const [topic0, topic1, topic2, topic3] = log.topics
    if (topic0 !== TRANSFER_EVENT_SIGNATURE) return null

    const from = '0x' + topic1.slice(26)
    const to = '0x' + topic2.slice(26)
    const id = topic3
    const data = log.data
    const memo = data === '0x' ? '' : data

    return { from, to, id, memo }
  } catch {
    return null
  }
}

async function fetchTokenData(
  parallelTokenAddress: string,
  tokenId: string,
  publicClient: PublicClient,
): Promise<{ underlyingERC20: string; owner: string; amount: string } | null> {
  try {
    const result = await publicClient.readContract({
      address: parallelTokenAddress as Hash,
      abi: PARALLEL_TOKEN_ABI,
      functionName: 'idToTokenData',
      args: [BigInt(tokenId)],
    })
    return {
      underlyingERC20: result[0],
      owner: result[1],
      amount: result[2].toString(),
    }
  } catch {
    return null
  }
}

const PARALLEL_TOKEN_ABI = [
  {
    inputs: [{ name: 'id', type: 'uint256' }],
    name: 'idToTokenData',
    outputs: [
      { name: 'underlyingERC20', type: 'address' },
      { name: 'owner', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
] as const

export declare namespace charge {
  type Defaults = {
    amount?: string
    currency?: string
    recipient?: string
    parallelToken?: string
  }

  type Parameters = {
    rpcUrl: string
    minConfirmations?: number
  } & Defaults
}
