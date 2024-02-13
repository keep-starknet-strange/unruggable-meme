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
    gap: '32',
  }),
])

export const hr = style([
  {
    height: '1px',
  },
  sprinkles({
    width: 'full',
    background: 'border1',
  }),
])

export const card = style([
  {
    flex: '1',
    minWidth: '208px',
  },
  sprinkles({
    borderRadius: '10',
    backgroundColor: 'bg2',
    paddingX: '24',
    paddingY: '16',
    borderColor: 'border2',
    borderWidth: '1px',
    borderStyle: 'solid',
  }),
])

export const errorContainer = sprinkles({
  paddingX: '8',
  paddingTop: '4',
  color: 'error',
})
