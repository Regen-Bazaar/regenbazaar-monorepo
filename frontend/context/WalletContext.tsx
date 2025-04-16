"use client"

import { createContext, useContext, useState, type ReactNode } from "react"
import albedo from "@albedo-link/intent"
import { supabase } from "@/utils/supabaseClient"

type WalletType = "albedo" | "freighter" | "metamask" | null

interface WalletContextType {
  walletAddress: string | null
  selectedWallet: WalletType
  userName: string | null
  isWalletModalOpen: boolean
  openMenuDropdown: boolean
  connectWallet: (wallet: WalletType) => Promise<void>
  disconnectWallet: () => void
  setWalletModalOpen: (isOpen: boolean) => void
  setOpenMenuDropdown: (isOpen: boolean) => void
  isConnected: () => boolean
  fetchUserName: (address?: string) => Promise<void>
  refreshUserData: () => Promise<void>
}

const WalletContext = createContext<WalletContextType | undefined>(undefined)

export const useWallet = () => {
  const context = useContext(WalletContext)
  if (!context) {
    throw new Error("useWallet must be used within a WalletProvider")
  }
  return context
}

export const WalletProvider = ({ children }: { children: ReactNode }) => {
  const [walletAddress, setWalletAddress] = useState<string | null>(null)
  const [selectedWallet, setSelectedWallet] = useState<WalletType>(null)
  const [userName, setUserName] = useState<string | null>(null)
  const [isWalletModalOpen, setWalletModalOpen] = useState(false)
  const [openMenuDropdown, setOpenMenuDropdown] = useState(false)

  // Function to check if wallet is connected
  const isConnected = () => {
    return !!walletAddress
  }

  // Function to fetch user name from database
  const fetchUserName = async (address?: string) => {
    try {
      const addressToUse = address || walletAddress

      if (!addressToUse) return

      const { data, error } = await supabase.from("users").select("name").eq("wallet_address", addressToUse).single()

      if (error) {
        if (error.code !== "PGRST116") {
          // Not found error
          console.error("Error fetching user name:", error)
        }
        setUserName(null)
        return
      }
      if (data) {
        console.log("Setting user name:", data.name); // Debugging log
        setUserName(data.name);
      } else {
        console.log("No user data received");
      }
    } catch (error) {
      console.error("Error in fetchUserName:", error)
      setUserName(null)
    }

  }

  // Function to refresh all user data
  const refreshUserData = async () => {
    await fetchUserName()
  }

  // Connect wallet function
  const connectWallet = async (wallet: WalletType) => {
    try {
      let pubkey: string | undefined

      if (wallet === "albedo") {
        if (typeof albedo !== "undefined") {
          const result = await albedo.publicKey()
          pubkey = result.pubkey
        } else {
          alert("Albedo is not available. Please visit https://albedo.link to set it up.")
          return
        }
      } else if (wallet === "freighter") {
        if (typeof window !== "undefined" && (window as any).freighterApi) {
          pubkey = await (window as any).freighterApi.getPublicKey()
        } else {
          alert("Freighter is not installed. Please install it.")
          return
        }
      } else if (wallet === "metamask") {
        if (typeof window !== "undefined" && (window as any).ethereum) {
          const accounts = await (window as any).ethereum.request({
            method: "eth_requestAccounts",
          })
          pubkey = accounts[0]
        } else {
          alert("Metamask is not installed. Please install it.")
          return
        }
      }

      if (pubkey) {
        setWalletAddress(pubkey)
        setSelectedWallet(wallet)
        setWalletModalOpen(false)

        // Fetch user name after wallet is connected
        await fetchUserName(pubkey)
      }
    } catch (error) {
      console.error("Wallet Connection Error:", error)
    }
  }

  // Disconnect wallet function
  const disconnectWallet = () => {
    setWalletAddress(null)
    setSelectedWallet(null)
    setUserName(null)
    setOpenMenuDropdown(false)
  }

  return (
    <WalletContext.Provider
      value={{
        walletAddress,
        selectedWallet,
        userName,
        isWalletModalOpen,
        openMenuDropdown,
        connectWallet,
        disconnectWallet,
        setWalletModalOpen,
        setOpenMenuDropdown,
        isConnected,
        fetchUserName,
        refreshUserData,
      }}
    >
      {children}
    </WalletContext.Provider>
  )
}

