import { forwardRef, useCallback } from 'react'

import { FormattableInput, FormattableInputProps } from '.'

type FloatInputProps = Omit<FormattableInputProps, 'formatInput'>

const FloatInput = forwardRef<HTMLInputElement, FloatInputProps>(({ ...props }, ref) => {
  const formatNumber = useCallback((value: string) => {
    if (!value.length) return ''

    if (!/^([0-9]+([.][0-9]{0,6})?|[0-9]+)$/.test(value)) return

    return value
  }, [])

  return <FormattableInput {...props} formatInput={formatNumber} ref={ref} />
})

FloatInput.displayName = 'FloatInput'

export default FloatInput
