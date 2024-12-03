import { useQuoteToken } from 'hooks'
import { BaseSyntheticEvent, useState } from 'react'
import { useParams } from 'react-router-dom'
import { PrimaryButton, SecondaryButton } from 'src/components/Button'
import FloatInput from 'src/components/Input/FloatInput'
import PercentInput from 'src/components/Input/PercentInput'
import useMemecoin from 'src/hooks/useMemecoin'
import Box from 'src/theme/components/Box'
import { Column, Row } from 'src/theme/components/Flex'
import * as Text from 'src/theme/components/Text'

import * as styles from './style.css'

const DEFAULT_SLIPPAGE = 0.5
const DEFAULT_AMOUNT = 0

export default function TokenBuyer() {
  const [slippage, setSlippage] = useState(DEFAULT_SLIPPAGE)
  const [amount, setAmount] = useState(DEFAULT_AMOUNT)

  // memecoin
  const { address: tokenAddress } = useParams()
  const { data: memecoin } = useMemecoin(tokenAddress)

  // quote token
  const quoteToken = useQuoteToken(memecoin?.isLaunched ? memecoin?.liquidity?.quoteToken : undefined)

  // function to handle change of input in Amount
  function handleAmount(event: BaseSyntheticEvent) {
    if (event.target.value == '') {
      setAmount(0)
      return
    }
    setAmount(parseFloat(event.target.value))
  }

  // function to handle change of input in Amount
  function handleSlippage(event: BaseSyntheticEvent) {
    if (event.target.value == '') {
      setAmount(0)
      return
    }
    setSlippage(parseFloat(event.target.value))
  }

  return (
    <Column marginTop="10" gap="16">
      <Row>
        <Text.HeadlineMedium marginBottom="12">Buy Token</Text.HeadlineMedium>
      </Row>
      <Row justifyContent="space-between" gap="16">
        <Box marginRight="24" className={styles.container2}>
          <Text.HeadlineSmall paddingRight="1">{quoteToken?.name}</Text.HeadlineSmall>
        </Box>
        <Row width="full" justifyContent="flex-end">
          <Box marginRight="24" className={styles.container2}>
            <Text.HeadlineSmall>Amount: </Text.HeadlineSmall>
          </Box>
          <FloatInput value={amount} onChange={handleAmount} width="full" maxWidth="180" minWidth="42" />
        </Row>
      </Row>
      <Row justifyContent="space-between" gap="16">
        <Box marginRight="24" className={styles.container2}>
          <Text.HeadlineSmall paddingRight="1">Slippage</Text.HeadlineSmall>
        </Box>
        <Row gap="8" width="auto">
          <SecondaryButton onClick={() => setSlippage(0.1)}>0.1%</SecondaryButton>
          <SecondaryButton onClick={() => setSlippage(0.5)}>0.5%</SecondaryButton>
          <SecondaryButton onClick={() => setSlippage(1)} marginRight="18">
            1%
          </SecondaryButton>
          <PercentInput value={slippage} onChange={handleSlippage} width="full" maxWidth="180" minWidth="42" />
        </Row>
      </Row>
      <PrimaryButton onClick={() => console.log('TODO: implement the buying functionality here')}>Buy</PrimaryButton>
    </Column>
  )
}
