import { Percent } from '@uniswap/sdk-core'

import { AMM } from '../constants/amms'
import { LiquidityType } from '../constants/misc'
import { Token } from './tokens'

type i129 = {
  mag: string
  sign: string
}

type EkuboPoolKey = {
  token0: string
  token1: string
  fee: string
  tickSpacing: string
  extension: string
}

type EkuboBounds = {
  lower: i129
  upper: i129
}

type BaseLiquidity = {
  type: LiquidityType
  lockManager: string
  unlockTime: number
  owner: string
  quoteToken: string
}

export type JediswapLiquidity = {
  type: LiquidityType.JEDISWAP_ERC20 | LiquidityType.STARKDEFI_ERC20
  lockPosition: string
  quoteAmount: string
} & Omit<BaseLiquidity, 'type'>

export type EkuboLiquidity = {
  type: LiquidityType.EKUBO_NFT
  ekuboId: string
  startingTick: number
  poolKey: EkuboPoolKey
  bounds: EkuboBounds
} & Omit<BaseLiquidity, 'type'>

type LaunchedLiquidity = JediswapLiquidity | EkuboLiquidity

export type BaseMemecoin = {
  address: string
  name: string
  symbol: string
  owner: string
  decimals: number
  totalSupply: string
}

export type LaunchedMemecoin =
  | {
      isLaunched: false
    }
  | {
      isLaunched: true
      quoteToken: Token | undefined
      launch: {
        teamAllocation: string
        blockNumber: number
      }
      liquidity: LaunchedLiquidity
    }

export type Memecoin = BaseMemecoin & LaunchedMemecoin

export type DeployData = {
  /** The name of the memecoin. */
  name: string

  /** The symbol of the memecoin. */
  symbol: string

  /** Owner address of the memecoin. */
  owner: string

  /** The initial supply of the memecoin. Must **not be** multiplied by 10^decimals. */
  initialSupply: string | string
}

type MemecoinBaseLaunchData = {
  /** The AMM to launch the memecoin on. */
  amm: AMM

  /** The team allocations. */
  teamAllocations: {
    /** The address of the allocation. */
    address: string

    /** The allocation of the team member. Must **not be** multiplied by 10^decimals. */
    amount: number | string
  }[]

  /** The hold limit as Percent object. */
  holdLimit: Percent

  /** The anti-bot feature period in seconds. For example, 1 hour is 3600 etc. */
  antiBotPeriod: number

  /** The quote token to use. Must be a `Token` object and must be supported. See `QUOTE_TOKENS` constant. */
  quoteToken: Token

  /** The starting market cap in USDC. */
  startingMarketCap: number | string
}

export type EkuboLaunchData = MemecoinBaseLaunchData & {
  /** The ekubo fees. */
  fees: Percent
}

export type StandardAMMLaunchData = MemecoinBaseLaunchData & {
  /** The liquidity lock period in seconds. */
  liquidityLockPeriod: number
}
