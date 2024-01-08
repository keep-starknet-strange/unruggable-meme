import { style } from '@vanilla-extract/css'
import { sprinkles, vars } from 'src/theme/css/sprinkles.css'

export const container = style([
  {
    padding: '16px 12px 12px',
    boxShadow: `0 0 16px ${vars.color.bg1}`,
  },
  sprinkles({
    maxWidth: '620',
    width: 'full',
    background: 'bg1',
    borderRadius: '10',
    border: 'light',
  }),
])
