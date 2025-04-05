"use client"

import { Dialog } from "@headlessui/react"
import { AnimatePresence, motion } from "framer-motion"
import { X } from "lucide-react"
import WalletMenuDropdown from "./WalletMenuDropdown"
import { useWallet } from "../context/WalletContext"

export default function ConnectWallet() {
  const {
    walletAddress,
    userName,
    isWalletModalOpen,
    openMenuDropdown,
    connectWallet,
    disconnectWallet,
    setWalletModalOpen,
    setOpenMenuDropdown,
    selectedWallet,
  } = useWallet()



  return (
    <AnimatePresence>
      {walletAddress ? (
        <div className="flex gap-4 items-center">
          <div className="relative">
            <button
              onClick={() => setOpenMenuDropdown(!openMenuDropdown)}
              className="text-sm dark:text-white bg-blue-500 text-white px-4 py-2 rounded-md cursor-pointer"
            >
              {userName ? (
                <span>{userName}</span>
              ) : (
                <span>
                  {walletAddress.substring(0, 6)}...{walletAddress.slice(-4)}
                </span>
              )}
            </button>

            <WalletMenuDropdown
              onClick={disconnectWallet}
              wallet={selectedWallet}
              openMenuDropdown={openMenuDropdown}
            />
          </div>
        </div>
      ) : (
        <div>
          <motion.button
            onClick={() => setWalletModalOpen(true)}
            className="text-gray-900 bg-white hover:bg-gray-100 border border-gray-200 focus:ring-4 focus:outline-none focus:ring-gray-100 font-medium rounded-lg text-sm px-5 py-2.5 text-center inline-flex items-center dark:focus:ring-gray-600 dark:bg-gray-800 dark:border-gray-700 dark:text-white dark:hover:bg-gray-700 me-2 mb-2"
          >
            Connect Wallet
          </motion.button>

          {/* Wallet Selection Modal */}
          <Dialog
            open={isWalletModalOpen}
            onClose={() => setWalletModalOpen(false)}
            className="fixed inset-0 flex items-center justify-center bg-black bg-opacity-50"
          >
            <Dialog.Panel className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow-lg relative w-96">
              <button
                onClick={() => setWalletModalOpen(false)}
                className="absolute top-2 right-2 text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
                aria-label="Close"
              >
                <X size={24} />
              </button>

              <Dialog.Title className="text-lg font-bold mb-4 text-gray-900 dark:text-white">
                Select Wallet
              </Dialog.Title>

              <motion.button
                onClick={() => connectWallet("albedo")}
                className="w-full text-gray-900 bg-white hover:bg-gray-100 border border-gray-200 focus:ring-4 focus:outline-none focus:ring-gray-100 font-medium rounded-lg text-sm px-5 py-2.5 text-center dark:focus:ring-gray-600 dark:bg-gray-800 dark:border-gray-700 dark:text-white dark:hover:bg-gray-700 mb-2"
              >
                Connect with Albedo
              </motion.button>
              <motion.button
                onClick={() => connectWallet("freighter")}
                className="w-full text-gray-900 bg-white hover:bg-gray-100 border border-gray-200 focus:ring-4 focus:outline-none focus:ring-gray-100 font-medium rounded-lg text-sm px-5 py-2.5 text-center dark:focus:ring-gray-600 dark:bg-gray-800 dark:border-gray-700 dark:text-white dark:hover:bg-gray-700 mb-2"
              >
                Connect with Freighter
              </motion.button>
              <motion.button
                onClick={() => connectWallet("metamask")}
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

