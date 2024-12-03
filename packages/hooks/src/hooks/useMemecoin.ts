import { UseQueryResult } from '@tanstack/react-query'
import { Memecoin } from 'core'

import { UseQueryProps } from '../types'
import { useQuery } from './internal/useQuery'
import { useFactory } from './useFactory'

export type UseMemecoinProps = UseQueryProps & {
  /** The address of the memecoin */
  address?: string
}

/**
 * Get a memecoin. Returns the results of both `getBaseMemecoin` and `getMemecoinLaunchData`.
 */
export function useMemecoin({
  address,
  ...props
}: UseMemecoinProps): UseQueryResult<Memecoin | undefined, Error | null> {
  const factory = useFactory()

  return useQuery({
    queryKey: ['memecoin', address],
    queryFn: async () => (address ? factory.getMemecoin(address) : undefined),
    enabled: Boolean(address),
    ...props,
  })
}
