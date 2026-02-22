import { useWriteContract, useWaitForTransactionReceipt } from "wagmi"
import { useQueryClient } from "@tanstack/react-query"
import type { Address } from "viem"
import {
  LENDING_POOL,
  lendingPoolAbi,
  erc20Abi,
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
