import JediswapPair from 'src/abis/JediswapPair.json'
import Multicall from 'src/abis/Multicall.json'
import { constants, json } from 'starknet'

// Class hashes

// eslint-disable-next-line import/no-unused-modules
export const TOKEN_CLASS_HASH = '0x016261bfec15670ecc794d922fe87b6c1a250090d489811debf1b9c8cfac1225'

export const FACTORY_ADDRESSES = {
  [constants.StarknetChainId.SN_GOERLI]: '0x00fc328c366f0e1eebb1c105f4ec595403e995eac84ea92588f44254d15f1f9b',
  [constants.StarknetChainId.SN_MAIN]: '0xdead',
}

export const ETH_ADDRESS = '0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7'

export const MULTICALL_ADDRESS = '0x01a33330996310a1e3fa1df5b16c1e07f0491fdd20c441126e02613b948f0225'

export const JEDISWAP_ETH_USDC = {
  [constants.StarknetChainId.SN_GOERLI]: '0x05a2b2b37f66157f767ea711cb4e034c40d41f2f5acf9ff4a19049fa11c1a884',
  [constants.StarknetChainId.SN_MAIN]: '0x04d0390b777b424e43839cd1e744799f3de6c176c7e32c1812a41dbd9c19db6a',
}

export const compiledMulticall = json.parse(JSON.stringify(Multicall))
export const compiledJediswapPair = json.parse(JSON.stringify(JediswapPair))
