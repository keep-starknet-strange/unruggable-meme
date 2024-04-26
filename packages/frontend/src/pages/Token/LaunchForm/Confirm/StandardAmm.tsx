import { Fraction } from '@uniswap/sdk-core'
import moment from 'moment'
import { useCallback, useMemo } from 'react'
import { AMM, AmmInfos } from 'src/constants/AMMs'
import { FACTORY_ADDRESSES } from 'src/constants/contracts'
import {
  LIQUIDITY_LOCK_FOREVER_TIMESTAMP,
  MAX_LIQUIDITY_LOCK_PERIOD,
  Selector,
  STARKNET_MAX_BLOCK_TIME,
} from 'src/constants/misc'
import useChainId from 'src/hooks/useChainId'
import {
  useHodlLimitForm,
  useLiquidityForm,
  useResetLaunchForm,
  useStandardAmmLiquidityForm,
  useTeamAllocation,
  useTeamAllocationTotalPercentage,
} from 'src/hooks/useLaunchForm'
import useMemecoin from 'src/hooks/useMemecoin'
import { useQuoteTokenPrice } from 'src/hooks/usePrice'
import useQuoteToken from 'src/hooks/useQuote'
import { useExecuteTransaction } from 'src/hooks/useTransactions'
import { parseFormatedAmount } from 'src/utils/amount'
import { decimalsScale } from 'src/utils/decimalScale'
import { CallData, uint256 } from 'starknet'

import { LastFormPageProps } from '../common'
import LaunchTemplate from './template'

interface StarndardAmmLaunchProps extends LastFormPageProps {
  amm: AMM.JEDISWAP | AMM.STARKDEFI
}

export default function StarndardAmmLaunch({ previous, amm }: StarndardAmmLaunchProps) {
  // form data
  const { hodlLimit, antiBotPeriod } = useHodlLimitForm()
  const { startingMcap, quoteTokenAddress } = useLiquidityForm()
  const { liquidityLockPeriod } = useStandardAmmLiquidityForm()
  const { teamAllocation } = useTeamAllocation()
  const resetLaunchForm = useResetLaunchForm()

  // memecoin
  const { data: memecoin, refresh: refreshMemecoin } = useMemecoin()

  // quote token price
  const quoteToken = useQuoteToken()
  const quoteTokenPrice = useQuoteTokenPrice(quoteTokenAddress)

  // team allocation
  const teamAllocationTotalPercentage = useTeamAllocationTotalPercentage(memecoin?.totalSupply)

  // quote amount
  const quoteAmount = useMemo(() => {
    if (!quoteTokenPrice || !startingMcap || !teamAllocationTotalPercentage) return

    // mcap / quote_token_price * (1 - team_allocation / total_supply)
    return new Fraction(parseFormatedAmount(startingMcap))
      .divide(quoteTokenPrice)
      .multiply(new Fraction(1).subtract(teamAllocationTotalPercentage))
  }, [teamAllocationTotalPercentage, startingMcap, quoteTokenPrice])

  // starknet
  const chainId = useChainId()

  // transaction
  const executeTransaction = useExecuteTransaction()

  // launch
  const launch = useCallback(() => {
    if (!quoteToken?.decimals || !quoteAmount || !chainId || !hodlLimit || !memecoin?.address) return

    const uin256QuoteAmount = uint256.bnToUint256(
      BigInt(quoteAmount.multiply(decimalsScale(quoteToken.decimals)).quotient.toString()),
    )

    const approveCalldata = CallData.compile([
      FACTORY_ADDRESSES[chainId], // spender
      uin256QuoteAmount,
    ])

    // team allocation
    const initalHolders = Object.values(teamAllocation)
      .filter(Boolean)
      .map((holder) => holder.address)
    const initalHoldersAmounts = Object.values(teamAllocation)
      .filter(Boolean)
      .map((holder) => uint256.bnToUint256(BigInt(parseFormatedAmount(holder.amount)) * BigInt(decimalsScale(18))))

    // prepare calldata
    const launchCalldata = CallData.compile([
      memecoin.address, // memecoin address
      antiBotPeriod * 60, // anti bot period in seconds
      +hodlLimit * 100, // hodl limit
      quoteTokenAddress, // quote token
      initalHolders, // initial holders
      initalHoldersAmounts, // intial holders amounts
      uin256QuoteAmount, // quote amount
      liquidityLockPeriod === MAX_LIQUIDITY_LOCK_PERIOD // liquidity lock until
        ? LIQUIDITY_LOCK_FOREVER_TIMESTAMP
        : moment().add(moment.duration(liquidityLockPeriod, 'months')).unix() + STARKNET_MAX_BLOCK_TIME,
    ])

    executeTransaction({
      calls: [
        {
          contractAddress: quoteTokenAddress,
          entrypoint: Selector.APPROVE,
          calldata: approveCalldata,
        },
        {
          contractAddress: FACTORY_ADDRESSES[chainId],
          entrypoint: AmmInfos[amm].launchEntrypoint,
          calldata: launchCalldata,
        },
      ],
      action: `Launch on ${amm}`,
      onSuccess: () => {
        resetLaunchForm()
        refreshMemecoin()
      },
    })
  }, [
    quoteToken?.decimals,
    amm,
    quoteAmount,
    chainId,
    hodlLimit,
    memecoin?.address,
    teamAllocation,
    antiBotPeriod,
    liquidityLockPeriod,
    executeTransaction,
    refreshMemecoin,
    resetLaunchForm,
    quoteTokenAddress,
  ])

  return <LaunchTemplate liquidityPrice={quoteAmount} previous={previous} next={launch} />
}
