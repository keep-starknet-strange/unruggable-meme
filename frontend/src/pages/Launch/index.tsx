import { Link } from 'react-router-dom'
import { PrimaryButton } from 'src/components/Button'
import Section from 'src/components/Section'
import { useDeploymentStore } from 'src/hooks/useDeployment'
import Box from 'src/theme/components/Box'
import { Column, Row } from 'src/theme/components/Flex'
import * as Text from 'src/theme/components/Text'

import * as styles from './style.css'
import TokenContract from './TokenContract'

export default function LaunchPage() {
  const { deployedTokenContracts } = useDeploymentStore()

  return (
    <Section>
      <Column className={styles.container}>
        <Row justifyContent="space-between">
          <Text.HeadlineMedium>Your deployed tokens</Text.HeadlineMedium>

          <Link to="/deploy">
            <PrimaryButton>Deploy a token</PrimaryButton>
          </Link>
        </Row>

        {deployedTokenContracts
          .sort((a, b) => (a.launched === b.launched ? 0 : a.launched ? 1 : -1))
          .map((tokenContract) => (
            <TokenContract key={tokenContract.address} tokenContract={tokenContract} />
          ))}

        {!deployedTokenContracts.length && (
          <Box className={styles.noTokensContainer}>
            <Text.Body textAlign="center">No tokens found.</Text.Body>
          </Box>
        )}
      </Column>
    </Section>
  )
}
