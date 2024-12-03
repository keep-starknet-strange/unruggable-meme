import { Fraction } from '@uniswap/sdk-core'
import { CallDetails, constants, ProviderInterface } from 'starknet'

import {
  BaseMemecoin,
  DeployData,
  EkuboLaunchData,
  LaunchedMemecoin,
  Memecoin,
  StandardAMMLaunchData,
} from '../types/memecoin'

export type FactoryConfig = {
  provider: ProviderInterface
  chainId: constants.StarknetChainId
}

// TODO: Add comments
export abstract class FactoryInterface {
  public abstract config: FactoryConfig

  /**
   * Get a memecoin. Returns the results of both `getBaseMemecoin` and `getMemecoinLaunchData`.
   * @param address Memecoin address
   */
  public abstract getMemecoin(address: string): Promise<Memecoin | undefined>

  /**
   * Get a memecoin's base details. This includes the memecoin's name, symbol, owner, decimals, and total supply.
   * @param address Memecoin address
   */
  public abstract getBaseMemecoin(address: string): Promise<BaseMemecoin | undefined>

  /**
   * Get a memecoin's launch details. This includes the memecoin's quote token, team allocations, and liquidity.
   * @param address Memecoin address
   */
  public abstract getMemecoinLaunchData(address: string): Promise<LaunchedMemecoin>

  /**
   * Get the collectable ekubo fees of a memecoin.
   * @param memecoin Result of `getMemecoin`
   */
  public abstract getEkuboFees(memecoin: Memecoin): Promise<Fraction | undefined>

  /**
   * Get the calldata to collect ekubo fees of a memecoin.
   * @param memecoin Result of `getMemecoin`
   */
  public abstract getCollectEkuboFeesCalldata(memecoin: Memecoin): { calls: CallDetails[] } | undefined

  /**
   * Get the calldata to extend the liquidity lock of a memecoin.
   * @param memecoin Result of `getMemecoin`
   * @param seconds Amount of time to extend the liquidity lock in seconds
   */
  public abstract getExtendLiquidityLockCalldata(
    memecoin: Memecoin,
    seconds: number,
  ): { calls: CallDetails[] } | undefined

  /**
   * Get the calldata to deploy a memecoin.
   * @param data Data to deploy a memecoin
   */
  public abstract getDeployCalldata(data: DeployData): { tokenAddress: string; calls: CallDetails[] }

  /**
   * Get the calldata to launch a deployed memecoin on Ekubo.
   * @param memecoin Result of `getMemecoin`
   * @param data Data to launch a memecoin
   */
  public abstract getEkuboLaunchCalldata(memecoin: Memecoin, data: EkuboLaunchData): Promise<{ calls: CallDetails[] }>

  /**
   * Get the calldata to launch a deployed memecoin on a standard AMM.
   * @param memecoin Result of `getMemecoin`
   * @param data Data to launch a memecoin
   */
  public abstract getStandardAMMLaunchCalldata(
    memecoin: Memecoin,
    data: StandardAMMLaunchData,
  ): Promise<{ calls: CallDetails[] }>
}
