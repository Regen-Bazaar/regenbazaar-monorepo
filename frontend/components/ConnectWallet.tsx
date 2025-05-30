"use client"
import { useState } from "react"
import { Dialog } from "@headlessui/react"
import albedo from "@albedo-link/intent"
import { AnimatePresence, motion } from "framer-motion"
import { X } from "lucide-react"
import { useWallet } from "../providers/wallet-context"

export default function ConnectWallet() {
  const { walletAddress, setWalletAddress, selectedWallet, setSelectedWallet } = useWallet()
  const [isOpen, setIsOpen] = useState(false)
  const [showDropdown, setShowDropdown] = useState(false)

  const handleConnect = async (wallet: string) => {
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
        if (typeof window !== "undefined" && window.freighterApi) {
          pubkey = await window.freighterApi.getPublicKey()
        } else {
          alert("Freighter is not installed. Please install it.")
          return
        }
      } else if (wallet === "metamask") {
        if (typeof window !== "undefined" && window.ethereum) {
          const accounts = await window.ethereum.request({
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
        setIsOpen(false)
      }
    } catch (error) {
      console.error("Wallet Connection Error:", error)
    }
  }

  const handleDisconnect = () => {
    setWalletAddress(null)
    setSelectedWallet(null)
    setShowDropdown(false)
  }

  return (
    <AnimatePresence>
      {walletAddress ? (
        <div className="flex items-center">
          <div className="relative">
            <button
              onClick={() => setShowDropdown(!showDropdown)}
              className="text-gray-900 bg-white hover:bg-gray-100 border border-gray-200 focus:ring-4 focus:outline-none focus:ring-gray-100 font-medium rounded-lg text-sm px-5 py-2.5 text-center inline-flex items-center dark:focus:ring-gray-600 dark:bg-gray-800 dark:border-gray-700 dark:text-white dark:hover:bg-gray-700"
            >
              {walletAddress.substring(0, 6)}...{walletAddress.slice(-4)}
            </button>

            {showDropdown && (
              <div className="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg py-1 z-10 dark:bg-gray-800">
                <button
                  onClick={handleDisconnect}
                  className="block w-full text-left px-4 py-2 text-gray-700 hover:bg-gray-100 dark:text-white dark:hover:bg-gray-700"
                >
                  Disconnect ({selectedWallet})
                </button>
              </div>
            )}
          </div>
        </div>
      ) : (
        <div>
          <motion.button
            onClick={() => setIsOpen(true)}
            className="text-gray-900 bg-white hover:bg-gray-100 border border-gray-200 focus:ring-4 focus:outline-none focus:ring-gray-100 font-medium rounded-lg text-sm px-5 py-2.5 text-center inline-flex items-center dark:focus:ring-gray-600 dark:bg-gray-800 dark:border-gray-700 dark:text-white dark:hover:bg-gray-700 me-2 mb-2"
          >
            Connect Wallet
          </motion.button>

          {/* Wallet Selection Modal */}
          <Dialog
            open={isOpen}
            onClose={() => setIsOpen(false)}
            className="fixed inset-0 flex items-center justify-center bg-black bg-opacity-50"
          >
            <Dialog.Panel className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow-lg relative w-96">
              <button
                onClick={() => setIsOpen(false)}
                className="absolute top-2 right-2 text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
                aria-label="Close"
              >
                <X size={24} />
              </button>

              <Dialog.Title className="text-lg font-bold mb-4 text-gray-900 dark:text-white">
                Select Wallet
              </Dialog.Title>

              <motion.button
                onClick={() => handleConnect("albedo")}
                className="w-full text-gray-900 bg-white hover:bg-gray-100 border border-gray-200 focus:ring-4 focus:outline-none focus:ring-gray-100 font-medium rounded-lg text-sm px-5 py-2.5 text-center dark:focus:ring-gray-600 dark:bg-gray-800 dark:border-gray-700 dark:text-white dark:hover:bg-gray-700 mb-2"
              >
                Connect with Albedo
              </motion.button>
              <motion.button
                onClick={() => handleConnect("freighter")}
                className="w-full text-gray-900 bg-white hover:bg-gray-100 border border-gray-200 focus:ring-4 focus:outline-none focus:ring-gray-100 font-medium rounded-lg text-sm px-5 py-2.5 text-center dark:focus:ring-gray-600 dark:bg-gray-800 dark:border-gray-700 dark:text-white dark:hover:bg-gray-700 mb-2"
              >
                Connect with Freighter
              </motion.button>
              <motion.button
                onClick={() => handleConnect("metamask")}
                className="w-full text-gray-900 bg-white hover:bg-gray-100 border border-gray-200 focus:ring-4 focus:outline-none focus:ring-gray-100 font-medium rounded-lg text-sm px-5 py-2.5 text-center dark:focus:ring-gray-600 dark:bg-gray-800 dark:border-gray-700 dark:text-white dark:hover:bg-gray-700"
              >
                Connect with Metamask
              </motion.button>
            </Dialog.Panel>
          </Dialog>
        </div>
      )}
    </AnimatePresence>
  )
}

