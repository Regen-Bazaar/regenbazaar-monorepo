"use client"

import { createContext, useState, useContext, type ReactNode } from "react"

interface WalletContextType {
  walletAddress: string | null
  setWalletAddress: (address: string | null) => void
  selectedWallet: string | null
  setSelectedWallet: (wallet: string | null) => void
}

const WalletContext = createContext<WalletContextType>({
  walletAddress: null,
  setWalletAddress: () => {},
  selectedWallet: null,
  setSelectedWallet: () => {},
})

export function WalletProvider({ children }: { children: ReactNode }) {
  const [walletAddress, setWalletAddress] = useState<string | null>(null)
  const [selectedWallet, setSelectedWallet] = useState<string | null>(null)

  return (
    <WalletContext.Provider
      value={{
        walletAddress,
        setWalletAddress,
        selectedWallet,
        setSelectedWallet,
      }}
    >
      {children}
    </WalletContext.Provider>
  )
}

export function useWallet() {
  return useContext(WalletContext)
}

