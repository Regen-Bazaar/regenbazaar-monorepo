"use client";

import { useState, useEffect } from "react";
// import { Provider, constants } from "starknet";

// ABI for the REBAZ token contract (simplified version)
// const rebazAbi = [
//   {
//     name: "balanceOf",
//     type: "function",
//     inputs: [{ name: "account", type: "felt" }],
//     outputs: [{ name: "balance", type: "Uint256" }],
//     stateMutability: "view",
//   },
// ];

// Replace with your actual REBAZ token contract address
// const REBAZ_ADDRESS = "0x...";

// // Starknet provider for testnet
// const starknetProvider = new Provider({
//   sequencer: { network: constants.NetworkName.SN_SEPOLIA },
// });

export default function TokenDisplay({
  walletAddress,
}: {
  walletAddress: string | null;
}) {
  const [rebazBalance, setRebazBalance] = useState<string>("0");
  const [rwiRank, setRwiRank] = useState<number>(0);
  const [isLoading, setIsLoading] = useState(false);
  const [userName, setUserName] = useState<string>("");

  useEffect(() => {
    const fetchTokenBalance = async () => {
      if (!walletAddress) return;

      setIsLoading(true);
      try {
        // For demonstration, using mock data
        // In production, replace with actual contract call:
        /*
        const contract = new Contract(rebazAbi, REBAZ_ADDRESS, starknetProvider);
        const response = await contract.balanceOf(walletAddress);
        const balance = response.balance.toString();
        setRebazBalance(balance);
        */

        // Mock data for demonstration
        setTimeout(() => {
          setRebazBalance("150");
          setRwiRank(70);
          setUserName("Paul Burg");
          setIsLoading(false);
        }, 500);
      } catch (error) {
        console.error("Error fetching REBAZ balance:", error);
        setIsLoading(false);
      }
    };

    fetchTokenBalance();
  }, [walletAddress]);

  if (!walletAddress) return null;

  return (
    <div className="flex items-center space-x-6">
      <a
        href="#"
        className="font-medium text-white hover:underline border-b border-white"
      >
        {userName}
      </a>

      <div className="flex items-center space-x-2">
        <span className="text-gray-400">RWI RANK:</span>
        {isLoading ? (
          <span className="w-6 h-4 bg-gray-600 animate-pulse rounded"></span>
        ) : (
          <span className="font-semibold text-green-500">{rwiRank}</span>
        )}
      </div>

      <div className="flex items-center space-x-2">
        <span className="text-gray-400">vo$REBAZ:</span>
        {isLoading ? (
          <span className="w-10 h-4 bg-gray-600 animate-pulse rounded"></span>
        ) : (
          <span className="font-semibold text-green-500">{rebazBalance}</span>
        )}
      </div>
    </div>
  );
}
