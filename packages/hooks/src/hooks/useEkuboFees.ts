import { UseQueryResult } from '@tanstack/react-query'
import { Fraction } from '@uniswap/sdk-core'

import { UseQueryProps } from '../types'
import { useQuery } from './internal/useQuery'
import { useFactory } from './useFactory'
import { useMemecoin } from './useMemecoin'

export interface UseEkuboFeesProps extends UseQueryProps {
  /** The address of the memecoin */
  address?: string
}

/**
 * Get the collectable ekubo fees for a memecoin.
 */
export function useEkuboFees({
  address,
  ...props
}: UseEkuboFeesProps): UseQueryResult<Fraction | undefined, Error | null> {
  const factory = useFactory()
  const memecoin = useMemecoin({ address })

  return useQuery({
    queryKey: ['ekuboFees', memecoin.data?.address],
    queryFn: async () => (memecoin.data ? factory.getEkuboFees(memecoin.data) : undefined),
    enabled: Boolean(address && memecoin.data),
    ...props,
  })
}
