"use client";

import { supabase } from "@/utils/supabaseClient";
import { useState } from "react";


export default function UserForm() {
  const [name, setName] = useState("");
  const [wallet, setWallet] = useState("");
  const [message, setMessage] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!name || !wallet) {
      setMessage("Both fields are required.");
      return;
    }

    // Check if wallet already exists
    const { data: existingUser } = await supabase
      .from("users")
      .select("id")
      .eq("wallet_address", wallet)
      .single();

    if (existingUser) {
      setMessage("Wallet address already registered!");
      return;
    }

    const { error } = await supabase
      .from("users")
      .insert([{ wallet_address: wallet, name }]);

    if (error) {
      setMessage("Error: " + error.message);
    } else {
      setMessage("User added successfully!");
      setName("");
      setWallet("");
    }
  };

  return (
    <div className="p-4 max-w-md mx-auto bg-white shadow-md rounded-md">
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
          />
        </div>

        <div className="mb-3">
          <label className="block text-sm font-medium">Wallet Address:</label>
          <input
            type="text"
            value={wallet}
            onChange={(e) => setWallet(e.target.value)}
            className="w-full p-2 border rounded-md"
            required
          />
        </div>

        <button
          type="submit"
          className="bg-blue-500 text-white px-4 py-2 rounded-md"
        >
          Submit
        </button>
      </form>

      {message && <p className="mt-3 text-center">{message}</p>}
    </div>
  );
}
