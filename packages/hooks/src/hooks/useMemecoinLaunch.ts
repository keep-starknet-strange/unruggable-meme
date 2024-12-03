import { UseQueryResult } from '@tanstack/react-query'
import { LaunchedMemecoin } from 'core'

import { UseQueryProps } from '../types'
import { useQuery } from './internal/useQuery'
import { useFactory } from './useFactory'

export type UseMemecoinLaunchProps = UseQueryProps & {
  /** The address of the memecoin */
  address?: string
}

/**
 * Get a memecoin's launch details. This includes the memecoin's quote token, team allocations, and liquidity.
 */
export function useMemecoinLaunch({
  address,
  ...props
}: UseMemecoinLaunchProps): UseQueryResult<LaunchedMemecoin | undefined, Error | null> {
  const factory = useFactory()

  return useQuery({
    queryKey: ['memecoinLaunchData', address],
    queryFn: async () => (address ? factory.getMemecoinLaunchData(address) : undefined),
    enabled: Boolean(address),
    ...props,
  })
}
