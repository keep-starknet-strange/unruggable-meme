import { Block, hash, shortString } from './deps.ts'
import { FACTORY_ADDRESS, STARTING_BLOCK } from './constants.ts'

const filter = {
  header: {
    weak: true,
  },
  events: [
    {
      fromAddress: FACTORY_ADDRESS,
      keys: [hash.getSelectorFromName('MemecoinLaunched')],
      includeReceipt: false,
    },
  ],
}

export const config = {
  streamUrl: 'https://mainnet.starknet.a5a.ch',
  startingBlock: STARTING_BLOCK,
  network: 'starknet',
  finality: 'DATA_STATUS_ACCEPTED',
  filter,
  sinkType: 'postgres',
  sinkOptions: {
    connectionString: '',
    tableName: 'unrugmeme_launch',
  },
}

export default function DecodeUnruggableMemecoinLaunch({ header, events }: Block) {
  const { blockNumber, blockHash, timestamp } = header!

  return (events ?? []).map(({ event, transaction }) => {
    if (!event.data) return

    const transactionHash = transaction.meta.hash

    const [memecoin_address, quote_token, exchange_name] = event.data

    const exchange_name_decoded = shortString.decodeShortString(exchange_name.replace(/0x0+/, '0x'))

    return {
      network: 'starknet-mainnet',
      block_hash: blockHash,
      block_number: Number(blockNumber),
      block_timestamp: timestamp,
      transaction_hash: transactionHash,
      memecoin_address: memecoin_address,
      quote_token: quote_token,
      exchange_name: exchange_name_decoded,
      created_at: new Date().toISOString(),
    }
  })
}
