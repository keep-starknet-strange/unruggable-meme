import { Fraction, Percent } from '@uniswap/sdk-core'
import { useMemo } from 'react'
import { DECIMALS } from 'src/constants/misc'
import { useBoundStore } from 'src/state'
import { parseFormatedAmount } from 'src/utils/amount'
import { decimalsScale } from 'src/utils/decimalScale'

export function useHodlLimitForm() {
  return useBoundStore((state) => ({
    hodlLimit: state.hodlLimit,
    antiBotPeriod: state.antiBotPeriod,
    setHodlLimit: state.setHodlLimit,
    setAntiBotPeriod: state.setAntiBotPeriod,
  }))
}

export function useLiquidityForm() {
  return useBoundStore((state) => ({
    liquidityLockPeriod: state.liquidityLockPeriod,
    startingMcap: state.startingMcap,
    setLiquidityLockPeriod: state.setLiquidityLockPeriod,
    setStartingMcap: state.setStartingMcap,
  }))
}

export function useLaunch() {
  return useBoundStore((state) => [state.launch, state.setLaunch] as const)
}

export function useTeamAllocation() {
  return useBoundStore((state) => ({
    teamAllocation: state.teamAllocation,
    setTeamAllocationHolder: state.setTeamAllocationHolder,
    removeTeamAllocationHolder: state.removeTeamAllocationHolder,
  }))
}

export function useTeamAllocationTotalPercentage(totalSupply: string) {
  const { teamAllocation } = useTeamAllocation()

  return useMemo(() => {
    const totalTeamAllocation = Object.values(teamAllocation).reduce(
      (acc, holder) => acc.add(parseFormatedAmount(holder?.amount ?? 0)),
      new Fraction(0)
    )

    return new Percent(totalTeamAllocation.quotient, new Fraction(totalSupply, decimalsScale(DECIMALS)).quotient)
  }, [totalSupply, teamAllocation])
}
