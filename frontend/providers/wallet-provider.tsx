"use client"

import type React from "react"

import { WagmiConfig, createConfig, configureChains } from "wagmi"
import { publicProvider } from "wagmi/providers/public"
import { InjectedConnector } from "wagmi/connectors/injected"
import { celo, celoAlfajores } from "wagmi/chains"

// Configure chains & providers
const { chains, publicClient, webSocketPublicClient } = configureChains([celo, celoAlfajores], [publicProvider()])

// Set up wagmi config
const config = createConfig({
  autoConnect: true,
  connectors: [
    new InjectedConnector({
      chains,
      options: {
        name: "Injected",
        shimDisconnect: true,
      },
    }),
  ],
  publicClient,
  webSocketPublicClient,
})

export function WalletProvider({ children }: { children: React.ReactNode }) {
  return <WagmiConfig config={config}>{children}</WagmiConfig>
}

