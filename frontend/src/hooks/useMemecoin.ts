import { useAccount, useProvider } from '@starknet-react/core'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { FACTORY_ADDRESSES, MULTICALL_ADDRESS } from 'src/constants/contracts'
import { Selector } from 'src/constants/misc'
import { CallData, getChecksumAddress, hash, shortString, uint256 } from 'starknet'

import useChainId from './useChainId'
import { useDeploymentStore } from './useDeployment'

interface MemecoinInfos {
  address: string
  name: string
  symbol: string
  maxSupply: string
  teamAllocation: string
  launched: boolean
  isOwner: boolean
  owner: string
}

export function useMemecoinInfos() {
  const [memecoinInfos, setMemecoinInfos] = useState<Omit<MemecoinInfos, 'isOwner'> | undefined>()
  const [error, setError] = useState<string | undefined>()
  const [indexing, setIndexing] = useState<boolean>(false)

  const { deployedTokenContracts } = useDeploymentStore()

  // starknet
  const { address } = useAccount()
  const { provider } = useProvider()
  const chainId = useChainId()

  // getter
  const getMemecoinInfos = useCallback(
    async (tokenAddress: string) => {
      if (!chainId) return

      setError(undefined)

      const isMemecoinCalldata = CallData.compile({
        to: FACTORY_ADDRESSES[chainId],
        selector: hash.getSelector(Selector.IS_MEMECOIN),
        calldata: [tokenAddress],
      })

      const nameCalldata = CallData.compile({
        to: tokenAddress,
        selector: hash.getSelector(Selector.NAME),
        calldata: [],
      })

      const symbolCalldata = CallData.compile({
        to: tokenAddress,
        selector: hash.getSelector(Selector.SYMBOL),
        calldata: [],
      })

      const launchedCalldata = CallData.compile({
        to: tokenAddress,
        selector: hash.getSelector(Selector.IS_LAUNCHED),
        calldata: [],
      })

      const totalSupplyCalldata = CallData.compile({
        to: tokenAddress,
        selector: hash.getSelector(Selector.TOTAL_SUPPLY),
        calldata: [],
      })

      const teamAllocationCalldata = CallData.compile({
        to: tokenAddress,
        selector: hash.getSelector(Selector.GET_TEAM_ALLOCATION),
        calldata: [],
      })

      const ownerCalldata = CallData.compile({
        to: tokenAddress,
        selector: hash.getSelector(Selector.OWNER),
        calldata: [],
      })

      const lockedLiquidity = CallData.compile({
        to: FACTORY_ADDRESSES[chainId],
        selector: hash.getSelector(Selector.LOCKED_LIQUIDITY),
        calldata: [tokenAddress],
      })

      try {
        const res = await provider?.callContract({
          contractAddress: MULTICALL_ADDRESS,
          entrypoint: Selector.AGGREGATE,
          calldata: [
            8,
            ...isMemecoinCalldata,
            ...nameCalldata,
            ...symbolCalldata,
            ...launchedCalldata,
            ...totalSupplyCalldata,
            ...teamAllocationCalldata,
            ...ownerCalldata,
            ...lockedLiquidity,
          ],
        })

        const isUnruggable = !!+res.result[3] // beautiful

        if (!isUnruggable) {
          setError('Not unruggable')
        }

        const memecoinInfos = {
          address: tokenAddress,
          name: shortString.decodeShortString(res.result[5]),
          symbol: shortString.decodeShortString(res.result[7]),
          launched: !!+res.result[9],
          maxSupply: uint256.uint256ToBN({ low: res.result[11], high: res.result[12] }).toString(),
          teamAllocation: uint256.uint256ToBN({ low: res.result[14], high: res.result[15] }).toString(),
          owner: getChecksumAddress(res.result[17]),
        }

        setMemecoinInfos(memecoinInfos)

        return memecoinInfos // still return memecoin infos
      } catch (err) {
        // might just not be already indexed
        for (const deployedTokenContract of deployedTokenContracts) {
          if (getChecksumAddress(deployedTokenContract.address) === getChecksumAddress(tokenAddress)) {
            setIndexing(true)
            return
          }
        }

        setError('Not unruggable')
      }

      return
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [chainId, provider, deployedTokenContracts.length]
  )

  // reset state
  useEffect(() => {
    setMemecoinInfos(undefined)
    setError(undefined)
  }, [])

  // isOwner
  const isOwner = useMemo(
    () => (memecoinInfos && address ? getChecksumAddress(address) === memecoinInfos.owner : false),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [address, memecoinInfos?.owner]
  )

  return [
    { data: memecoinInfos ? { ...memecoinInfos, isOwner } : undefined, error, indexing },
    getMemecoinInfos,
  ] as const
}
