"use client"

import type React from "react"

import { useWallet } from "@/context/WalletContext"
import { supabase } from "@/utils/supabaseClient"
import { useState } from "react"

interface UserFormProps {
  closeNameModal: () => void
}

export default function UserForm({ closeNameModal }: UserFormProps) {
  const { walletAddress, refreshUserData } = useWallet()
  const [name, setName] = useState("")
  const [wallet, setWallet] = useState(walletAddress)
  const [message, setMessage] = useState("")
  const [isLoading, setIsLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setIsLoading(true)

    if (!name || !wallet) {
      setMessage("Both fields are required.")
      setIsLoading(false)
      return
    }

    try {
      // Check if wallet already exists
      const { data: existingUser, error: queryError } = await supabase
        .from("users")
        .select("id")
        .eq("wallet_address", wallet)
        .single()

      if (queryError && queryError.code !== "PGRST116") {
        // Error other than "no rows returned"
        throw new Error(queryError.message)
      }

      if (existingUser) {
        // Update existing user
        const { error: updateError } = await supabase.from("users").update({ name }).eq("wallet_address", wallet)

        if (updateError) {
          throw new Error(updateError.message)
        }

        setMessage("Username updated successfully!")
      } else {
        // Insert new user
        const { error } = await supabase.from("users").insert([{ wallet_address: wallet, name }])

        if (error) {
          throw new Error(error.message)
        }

        setMessage("User added successfully!")
      }

      // Refresh user data in context to update the UI
      await refreshUserData()

      // Auto-close the modal after successful registration
      setTimeout(() => {
        closeNameModal()
      }, 2000)
    } catch (error) {
      console.error("Error:", error)
      setMessage(`Error: ${error instanceof Error ? error.message : "Unknown error occurred"}`)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="w-full h-screen fixed top-0 left-0 flex items-center justify-center text-black bg-black/70">
      <div className="p-4 max-w-md w-full mx-auto bg-white shadow-md rounded-md">
        <h2 className="text-xl font-bold mb-4">Register Wallet</h2>
        <form onSubmit={handleSubmit}>
          <div className="mb-3">
            <label className="block text-sm font-medium">Username:</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full p-2 border rounded-md"
              required
              disabled={isLoading}
            />
          </div>

          <div className="mb-3">
            <label className="block text-sm font-medium">Wallet Address:</label>
            <input
              placeholder={wallet || ""}
              type="text"
              value={wallet || ""}
              className="w-full p-2 border rounded-md bg-gray-50"
              readOnly
            />
          </div>

          <div className="flex space-x-2">
            <button
              type="submit"
              className={`bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-600 transition-colors ${
                isLoading ? "opacity-70 cursor-not-allowed" : ""
              }`}
              disabled={isLoading}
            >
              {isLoading ? "Submitting..." : "Submit"}
            </button>
            <button
              type="button"
              onClick={closeNameModal}
              className="px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-100"
              disabled={isLoading}
            >
              Close
            </button>
          </div>
        </form>

        {message && (
          <p
            className={`mt-3 text-center p-2 rounded ${
              message.includes("Error") ? "bg-red-100 text-red-700" : "bg-green-100 text-green-700"
            }`}
          >
            {message}
          </p>
        )}
      </div>
    </div>
  )
}

