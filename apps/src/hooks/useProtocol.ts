import { useReadContract, useReadContracts } from "wagmi"
import type { Address } from "viem"
import {
  LENDING_POOL,
  MOCK_PRICE_ORACLE,
  TOKENS,
  lendingPoolAbi,
  oracleAbi,
  riskRegistryAbi,
  erc20Abi,
} from "@/config/contracts"

// --- RiskRegistry address (fetched once from pool) ---

export function useRiskRegistryAddress() {
  return useReadContract({
    address: LENDING_POOL,
    abi: lendingPoolAbi,
    functionName: "riskRegistry",
  })
}

// --- Token Prices ---

export function useTokenPrices() {
  return useReadContracts({
    contracts: TOKENS.map((t) => ({
      address: MOCK_PRICE_ORACLE,
      abi: oracleAbi,
      functionName: "getPrice" as const,
      args: [t.address] as const,
    })),
  })
}

// --- Market Status ---

export function useMarketStatus() {
  return useReadContracts({
    contracts: TOKENS.map((t) => ({
      address: MOCK_PRICE_ORACLE,
      abi: oracleAbi,
      functionName: "isMarketOpen" as const,
      args: [t.address] as const,
    })),
  })
}

// --- User Position ---

export function useUserPosition(userAddress: Address | undefined) {
  const enabled = !!userAddress

  const debt = useReadContract({
    address: LENDING_POOL,
    abi: lendingPoolAbi,
    functionName: "getUserDebt",
    args: userAddress ? [userAddress] : undefined,
    query: { enabled },
  })

  const healthFactor = useReadContract({
    address: LENDING_POOL,
    abi: lendingPoolAbi,
    functionName: "getHealthFactor",
    args: userAddress ? [userAddress] : undefined,
    query: { enabled },
  })

  const maxBorrow = useReadContract({
    address: LENDING_POOL,
    abi: lendingPoolAbi,
    functionName: "getMaxBorrow",
    args: userAddress ? [userAddress] : undefined,
    query: { enabled },
  })

  const collaterals = useReadContracts({
    contracts: TOKENS.map((t) => ({
      address: LENDING_POOL,
      abi: lendingPoolAbi,
      functionName: "getUserCollateral" as const,
      args: userAddress ? [userAddress, t.address] as const : undefined,
    })),
    query: { enabled },
  })

  return {
    debt,
    healthFactor,
    maxBorrow,
    collaterals,
    isLoading: debt.isLoading || healthFactor.isLoading || maxBorrow.isLoading || collaterals.isLoading,
    refetch: () => {
      debt.refetch()
      healthFactor.refetch()
      maxBorrow.refetch()
      collaterals.refetch()
    },
  }
}

// --- Token Balances ---

export function useTokenBalances(userAddress: Address | undefined) {
  return useReadContracts({
    contracts: TOKENS.map((t) => ({
      address: t.address as Address,
      abi: erc20Abi,
      functionName: "balanceOf" as const,
      args: userAddress ? [userAddress] as const : undefined,
    })),
    query: { enabled: !!userAddress },
  })
}

// --- Protocol Stats ---

export function useProtocolStats() {
  return useReadContracts({
    contracts: [
      { address: LENDING_POOL, abi: lendingPoolAbi, functionName: "totalBorrowAmount" as const },
      { address: LENDING_POOL, abi: lendingPoolAbi, functionName: "totalBorrowShares" as const },
      { address: LENDING_POOL, abi: lendingPoolAbi, functionName: "borrowIndex" as const },
      { address: LENDING_POOL, abi: lendingPoolAbi, functionName: "reserves" as const },
      { address: LENDING_POOL, abi: lendingPoolAbi, functionName: "reserveFactor" as const },
    ],
  })
}

// --- Pool WETH Balance ---

export function usePoolWethBalance() {
  const weth = TOKENS.find((t) => t.symbol === "WETH")!
  return useReadContract({
    address: weth.address as Address,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [LENDING_POOL],
  })
}

// --- Risk Params ---

export function useRiskParams() {
  const { data: registryAddr } = useRiskRegistryAddress()

  return useReadContracts({
    contracts: TOKENS.map((t) => ({
      address: registryAddr as Address,
      abi: riskRegistryAbi,
      functionName: "getRiskParams" as const,
      args: [t.address] as const,
    })),
    query: { enabled: !!registryAddr },
  })
}

// --- Single Allowance ---

export function useAllowance(
  token: Address | undefined,
  owner: Address | undefined,
  spender: Address | undefined,
) {
  return useReadContract({
    address: token,
    abi: erc20Abi,
    functionName: "allowance",
    args: owner && spender ? [owner, spender] : undefined,
    query: { enabled: !!token && !!owner && !!spender },
  })
}
