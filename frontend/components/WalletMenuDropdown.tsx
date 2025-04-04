"use client"

import { useState } from "react"
import UserForm from "./UserForm"
import { useWallet } from "@/context/WalletContext"

interface WalletMenuDropdownProps {
  onClick: () => void
  wallet: "albedo" | "freighter" | "metamask" | null
  openMenuDropdown: boolean
}

export default function WalletMenuDropdown({ onClick, wallet, openMenuDropdown }: WalletMenuDropdownProps) {
  const [openNameModal, setOpenNameModal] = useState(false)
  const { userName } = useWallet()

  const closeNameModal = () => {
    setOpenNameModal(false)
  }

  return (
    <div
      className={`w-[200px] absolute top-[120%] left-[-25%] bg-white flex flex-col items-stretch justify-start gap-1 rounded-sm overflow-hidden transition-all duration-150 ease-in-out ${openMenuDropdown ? "h-fit py-3 " : "h-0"}`}
    >
      {userName && (
        <div className="py-2 px-4 text-black font-medium border-b border-gray-200">Signed in as {userName}</div>
      )}

      <button
        onClick={onClick}
        className="py-2 px-4 cursor-pointer border-b border-gray-900 text-black whitespace-nowrap"
      >
        Disconnect ({wallet})
      </button>

      <button onClick={() => setOpenNameModal(true)} className="py-2 px-4 cursor-pointer text-black">
        {userName ? "Change name" : "Add name"}
      </button>

      {openNameModal && <UserForm closeNameModal={closeNameModal} />}
    </div>
  )
}

