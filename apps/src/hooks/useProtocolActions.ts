import { useWriteContract, useWaitForTransactionReceipt } from "wagmi"
import { useQueryClient } from "@tanstack/react-query"
import type { Address } from "viem"
import {
  LENDING_POOL,
  MOCK_PRICE_ORACLE,
  lendingPoolAbi,
  erc20Abi,
  oracleAbi,
  TOKENS,
  DEFAULT_PRICES,
} from "@/config/contracts"

function useContractWrite() {
  const queryClient = useQueryClient()
  const write = useWriteContract()
  const receipt = useWaitForTransactionReceipt({ hash: write.data })

  // Invalidate all read queries on success
  if (receipt.isSuccess) {
    queryClient.invalidateQueries()
  }

  return {
    write: write.writeContract,
    hash: write.data,
    isPending: write.isPending,
    isConfirming: receipt.isLoading,
    isSuccess: receipt.isSuccess,
    error: write.error || receipt.error,
    reset: write.reset,
  }
}

export function useApprove() {
  const tx = useContractWrite()
  return {
    ...tx,
    approve: (token: Address, spender: Address, amount: bigint) =>
      tx.write({
        address: token,
        abi: erc20Abi,
        functionName: "approve",
        args: [spender, amount],
      }),
  }
}

export function useDeposit() {
  const tx = useContractWrite()
  return {
    ...tx,
    deposit: (asset: Address, amount: bigint) =>
      tx.write({
        address: LENDING_POOL,
        abi: lendingPoolAbi,
        functionName: "deposit",
        args: [asset, amount],
      }),
  }
}

export function useWithdraw() {
  const tx = useContractWrite()
  return {
    ...tx,
    withdraw: (asset: Address, receiptAmount: bigint) =>
      tx.write({
        address: LENDING_POOL,
        abi: lendingPoolAbi,
        functionName: "withdraw",
        args: [asset, receiptAmount],
      }),
  }
}

export function useBorrow() {
  const tx = useContractWrite()
  return {
    ...tx,
    borrow: (amount: bigint) =>
      tx.write({
        address: LENDING_POOL,
        abi: lendingPoolAbi,
        functionName: "borrow",
        args: [amount],
      }),
  }
}

export function useRepay() {
  const tx = useContractWrite()
  return {
    ...tx,
    repay: (amount: bigint) =>
      tx.write({
        address: LENDING_POOL,
        abi: lendingPoolAbi,
        functionName: "repay",
        args: [amount],
      }),
  }
}

export function useLiquidate() {
  const tx = useContractWrite()
  return {
    ...tx,
    liquidate: (borrower: Address, collateralAsset: Address, debtToRepay: bigint) =>
      tx.write({
        address: LENDING_POOL,
        abi: lendingPoolAbi,
        functionName: "liquidate",
        args: [borrower, collateralAsset, debtToRepay],
      }),
  }
}

export function useRefreshPrices() {
  const tx = useContractWrite()
  return {
    ...tx,
    refreshPrices: () => {
      const assets = TOKENS.map((t) => t.address) as Address[]
      const prices = TOKENS.map((t) => DEFAULT_PRICES[t.symbol])
      tx.write({
        address: MOCK_PRICE_ORACLE,
        abi: oracleAbi,
        functionName: "setPrices",
        args: [assets, prices],
      })
    },
  }
}

export function useSetMarketStatus() {
  const tx = useContractWrite()
  return {
    ...tx,
    setMarketStatus: (asset: Address, open: boolean) =>
      tx.write({
        address: MOCK_PRICE_ORACLE,
        abi: oracleAbi,
        functionName: "setMarketStatus",
        args: [asset, open],
      }),
  }
}
