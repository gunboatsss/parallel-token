import { Method, z } from 'mppx'

export const charge = Method.from({
  name: 'parallelToken',
  intent: 'charge',
  schema: {
    credential: {
      payload: z.object({
        tokenId: z.string(),
        txHash: z.string(),
      }),
    },
    request: z.object({
      amount: z.string(),
      currency: z.string(),
      recipient: z.string(),
      parallelToken: z.string(),
    }),
  },
})
