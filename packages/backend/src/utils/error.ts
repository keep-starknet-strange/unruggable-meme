const ErrorCodesArray = ['BAD_REQUEST', 'TOKEN_NOT_FOUND'] as const

export type ErrorCode = (typeof ErrorCodesArray)[number]

export const ErrorCode = Object.fromEntries(ErrorCodesArray.map((code) => [code, code])) as {
  [code in ErrorCode]: code
}
